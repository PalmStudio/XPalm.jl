PlantSimEngine.@process "geometry" verbose = false

"""
    GeometryModel(;vpalm_parameters, rng=Random.MersenneTwister())

A PlantSimEngine model that builds the 3D geometry for a leaf, including the petiole, rachis, and leaflets.
This model operates at the internode scale and modifies the MTG directly.

# Arguments

- `vpalm_parameters::Dict{String,Any}`: VPalm model parameters.
- `rng::Random.AbstractRNG`: Random number generator for stochastic processes.

# Inputs

- `is_pruned`: Whether the target Leaf has actually been pruned.
- `height_internodes`: Height of the target Internode.
- `radius_internodes`: Radius of the target Internode.
- `biomass_leaves`: Biomass of the Leaf attached to the target Internode.
- `rank_leaves`: Rank of the Leaf attached to the target Internode.

# Outputs

This model has no outputs as it modifies the MTG directly by adding geometric properties and child nodes.

# Notes

The model requires access to the VPalm parameters via the parameters dictionary under the "vpalm" key.
"""
struct GeometryModel{I,T,D<:AbstractDict{String},W} <: AbstractGeometryModel
    graph_node_count_init::I
    vpalm_parameters::D
    rng::T
    rachis_workspace::W
end

function GeometryModel(graph_node_count_init, vpalm_parameters, rng)
    return GeometryModel(
        graph_node_count_init,
        vpalm_parameters,
        rng,
        RachisBiomechanicsWorkspace(vpalm_parameters),
    )
end

function GeometryModel(; mtg::Node, vpalm_parameters, rng)
    GeometryModel(length(mtg), vpalm_parameters, rng)
end

function PlantSimEngine.inputs_(m::GeometryModel)
    (
        graph_node_count=PlantSimEngine.Default(m.graph_node_count_init),
        is_pruned=PlantSimEngine.Required(Bool),
        height_internodes=PlantSimEngine.Required(Real),
        radius_internodes=PlantSimEngine.Required(Real),
        biomass_leaves=PlantSimEngine.Required(Real),
        rank_leaves=PlantSimEngine.Required(Real),
    )
end

function PlantSimEngine.outputs_(::GeometryModel)
    (is_reconstructed=false, geometry_removed=false)
end

PlantSimEngine.variable_contracts_(::GeometryModel) = (
    biomass_leaves=PlantSimEngine.VariableContract(
        unit=:g_dry_matter,
        basis=:object,
        aggregation=:state,
        extent=:extensive,
    ),
)

"""
run!(model, status, environment, constants, context)

Builds the 3D geometry for a leaf by adding internode properties and creating child nodes for
petiole, rachis, and leaflets.

# Arguments

- `model::GeometryModel`: The leaf geometry model
- `status`: The status of the model with pruning, height, radius, biomass, and rank inputs.
- `environment`: Meteorology structure (not used by this model)
- `constants`: Physical constants (not used by this model)
- `context`: PlantSimEngine runtime context used to resolve the source MTG node.

# Notes

PlantSimEngine owns runtime status in its object registry. The declared
Internode and Leaf inputs carry the scientific values used for reconstruction;
the source MTG is used only for topology and geometry.
"""
function PlantSimEngine.run!(model::GeometryModel, status, environment, constants, context)
    internode = PlantSimEngine.source_node(context)
    leaf = only(node for node in children(internode) if symbol(node) == :Leaf)

    if status.is_pruned
        leaf.is_alive = false # This is used in the reconstruction for putting snags
        # Pruning is irreversible in XPalm. Record the lifecycle event on the
        # PlantSimEngine status so both MTG descendants and any registered
        # geometry objects are removed exactly once.
        if !status.geometry_removed
            remove_leaf_geometry!(leaf, context)
            status.geometry_removed = true
        end
        return nothing
    end

    # Get the unique MTG ID
    unique_mtg_id = PlantSimEngine.refvalue(status, :graph_node_count)

    symbol(leaf) != :Leaf && error("Expected leaf node, got $(symbol(leaf))")

    biomass_leaf_value = status.biomass_leaves
    biomass_leaf = uconvert(u"kg", max(0.0, biomass_leaf_value) * u"g")
    # VPalm parameters:
    vpalm_params = model.vpalm_parameters

    i = index(internode)
    _update_internode_properties!(internode, status, vpalm_params, model.rng)

    # Set leaf properties
    rank_new = status.rank_leaves
    if !status.is_reconstructed && any(node -> symbol(node) == :Petiole, children(leaf))
        # The seed leaf is initialized with a VPalm subtree before the
        # CompositeModel is built. Reuse it instead of creating a duplicate.
        status.is_reconstructed = true
    end
    leaf.is_alive = true

    current_length = final_rachis_length(i, biomass_leaf, vpalm_params)

    # Leaf properties depend on rank and final rachis length. Recomputing them
    # on unchanged days needlessly resampled the stochastic C-point angle and
    # dominated the steady-state geometry path. Child geometry still changes
    # only at the same discrete rank transitions as before.
    rank_changed, _ = _update_leaf_properties_if_needed!(
        leaf,
        rank_new,
        current_length,
        vpalm_params,
        model.rng,
    )
    isnan(leaf.rachis_length) && error("Rachis length: $(leaf.rachis_length), leaf_rank: $(leaf.rank), final_length: $current_length, biomass: $biomass_leaf")

    # Internal primordia exist in XPalm's MTG but are not yet visible organs.
    # Delay construction until the leaf enters the sheath; topology then stays
    # fixed while rank-dependent angles and expansion are updated.
    is_visible_leaf_rank(rank_new, vpalm_params) || return nothing

    if !haskey(vpalm_params, "rachis_length_age_intercept") && biomass_leaf_value <= 0.0
        return nothing
    end

    # Building a visible leaf and updating it at a rank transition are the only
    # events that require the expensive fresh-mass conversion and biomechanical
    # reconstruction. An ordinary unchanged day stops here.
    (!status.is_reconstructed || rank_changed) || return nothing

    rachis_fresh_biomass = rachis_fresh_biomass_for_geometry(
        leaf.rachis_length,
        biomass_leaf,
        vpalm_params,
    )
    if !status.is_reconstructed
        status.graph_node_count += 1
        build_leaf(unique_mtg_id, i, leaf, rachis_fresh_biomass, vpalm_params; rng=model.rng)
    elseif rank_changed
        update_leaf!(
            leaf,
            rachis_fresh_biomass,
            vpalm_params;
            rng=model.rng,
            workspace=model.rachis_workspace,
        )
    end

    status.is_reconstructed = true

    return nothing
end

"""
    _update_internode_properties!(internode, status, parameters, rng)

Synchronize internode dimensions and rank with XPalm status. These cheap,
deterministic assignments remain allocation-free on the steady-state path. The
phyllotactic angle is sampled only when the internode receives that property
for the first time; it is an organ-level trait, not a daily stochastic state.

Return `true` when the phyllotactic angle was initialized.
"""
function _update_internode_properties!(internode, status, parameters, rng)
    internode.width = status.radius_internodes * 2.0u"m"
    internode.length = status.height_internodes * u"m"
    internode.rank = status.rank_leaves
    internode.Orthotropy = 0.05u"°"

    if !hasproperty(internode, :XEuler)
        internode.XEuler = phyllotactic_angle(
            parameters["phyllotactic_angle_mean"],
            parameters["phyllotactic_angle_sd"];
            rng=rng,
        )
        return true
    end

    return false
end

"""
    _update_leaf_properties_if_needed!(leaf, rank, final_length, parameters, rng)

Recompute the leaf-scale allometry only when its rank, expected rachis length,
or required attributes changed. Return `(rank_changed, properties_changed)`.
"""
function _update_leaf_properties_if_needed!(leaf, rank, final_length, parameters, rng)
    rank_changed = !hasproperty(leaf, :rank) || leaf.rank != rank
    properties_missing =
        !hasproperty(leaf, :zenithal_insertion_angle) ||
        !hasproperty(leaf, :rachis_length) ||
        !hasproperty(leaf, :zenithal_cpoint_angle)
    expected_rachis_length = rachis_expansion(rank, final_length)
    length_changed =
        !properties_missing && leaf.rachis_length != expected_rachis_length
    properties_changed = rank_changed || properties_missing || length_changed

    leaf.rank = rank
    if properties_changed
        compute_properties_leaf!(leaf, rank, final_length, parameters, rng)
    end

    return rank_changed, properties_changed
end

const LEAF_GEOMETRY_SCALES = (
    :Petiole,
    :PetioleSegment,
    :Rachis,
    :RachisSegment,
    :Leaflet,
)

function remove_leaf_geometry!(leaf, context)
    model = PlantSimEngine.runtime_model(context)
    leaf_object = PlantSimEngine.model_object(model, leaf)

    # Remove registered geometry objects first so future applications cannot
    # keep targeting nodes that are about to disappear from the source MTG.
    for child_id in copy(leaf_object.children)
        child = PlantSimEngine.model_object(model, child_id)
        child.scale in LEAF_GEOMETRY_SCALES || continue
        PlantSimEngine.remove_object!(model, child_id; recursive=true)
    end

    # Geometry created dynamically is not currently registered as a model
    # object. Remove both registered and unregistered descendants from the MTG.
    delete_nodes!(leaf; filter_fun=node -> node !== leaf)
    return nothing
end


function build_leaf(unique_mtg_id, i, leaf, biomass_leaf, parameters; rng)
    # Build the petiole
    petiole_node = petiole(
        unique_mtg_id, leaf, i, 5,
        leaf.rachis_length,
        leaf.zenithal_insertion_angle,
        leaf.zenithal_cpoint_angle,
        parameters;
        rng=rng
    )

    # Build the rachis
    rachis_node = rachis(
        unique_mtg_id, petiole_node, i, 5, leaf.rank,
        leaf.rachis_length,
        petiole_node.height_cpoint,
        petiole_node.width_cpoint,
        leaf.zenithal_cpoint_angle,
        biomass_leaf,
        parameters;
        rng=rng
    )

    # Add the leaflets to the rachis
    leaflets!(
        unique_mtg_id, rachis_node, 5,
        leaf.rank, leaf.rachis_length,
        parameters;
        rng=rng
    )

end


function update_leaf!(leaf, biomass_leaf, parameters; rng, workspace=nothing)
    last_rank_unfolding = 2
    petiole = leaf[1]
    VPalm.update_petiole!(
        petiole,
        leaf.rachis_length,
        leaf.zenithal_insertion_angle,
        leaf.zenithal_cpoint_angle,
        parameters,
    )
    rachis = petiole[2]

    VPalm.update_rachis_angles!(
        rachis,
        leaf.rank,
        leaf.rachis_length,
        petiole.height_cpoint,
        petiole.width_cpoint,
        leaf.zenithal_cpoint_angle,
        biomass_leaf,
        parameters;
        rng=rng,
        workspace=workspace,
    )

    # Leaflet angles and segment profiles reach their final state at rank 2.
    # Later rank transitions can still change the petiole and rachis geometry,
    # but traversing every leaflet would only rebuild identical profiles.
    leaf.rank > last_rank_unfolding && return nothing

    traverse!(rachis, symbol=:Leaflet) do leaflet
        VPalm.update_leaflet_angles!(
            leaflet, leaf.rank;
            last_rank_unfolding=last_rank_unfolding,
            xm_intercept=parameters["leaflet_xm_intercept"], xm_slope=parameters["leaflet_xm_slope"],
            ym_intercept=parameters["leaflet_ym_intercept"], ym_slope=parameters["leaflet_ym_slope"]
        )
    end
    return nothing
end
