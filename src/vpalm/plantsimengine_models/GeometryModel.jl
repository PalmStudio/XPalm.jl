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
- `final_potential_area_leaves`: Potential one-sided leaflet area at maturity.
- `biomass_leaflets`: Simulated structural leaflet dry mass (gDM).
- `biomass_rachis`: Simulated structural rachis dry mass (gDM).
- `biomass_petiole`: Simulated structural petiole dry mass (gDM).
- `rank_leaves`: Rank of the Leaf attached to the target Internode.

# Outputs

This model has no outputs as it modifies the MTG directly by adding geometric properties and child nodes.

# Notes

The model requires access to the VPalm parameters via the parameters dictionary under the "vpalm" key.
"""
struct GeometryModel{I,T,D<:AbstractDict{String},W,F} <: AbstractGeometryModel
    graph_node_count_init::I
    vpalm_parameters::D
    rng::T
    rachis_workspace::W
    lma_min::F
    leaflets_biomass_contribution::F
    rachis_biomass_contribution::F
end

function GeometryModel(
    graph_node_count_init,
    vpalm_parameters,
    rng;
    lma_min=80.0,
    leaflets_biomass_contribution=0.30,
    rachis_biomass_contribution=0.30,
)
    mass_parameters = promote(
        lma_min,
        leaflets_biomass_contribution,
        rachis_biomass_contribution,
    )
    return GeometryModel(
        graph_node_count_init,
        vpalm_parameters,
        rng,
        RachisBiomechanicsWorkspace(vpalm_parameters),
        mass_parameters...,
    )
end

function GeometryModel(; mtg::Node, vpalm_parameters, rng, kwargs...)
    GeometryModel(length(mtg), vpalm_parameters, rng; kwargs...)
end

function PlantSimEngine.inputs_(m::GeometryModel)
    (
        graph_node_count=PlantSimEngine.Default(m.graph_node_count_init),
        is_pruned=PlantSimEngine.Required(Bool),
        height_internodes=PlantSimEngine.Required(Real),
        radius_internodes=PlantSimEngine.Required(Real),
        final_potential_area_leaves=PlantSimEngine.Required(Real),
        biomass_leaflets=PlantSimEngine.Required(Real),
        biomass_rachis=PlantSimEngine.Required(Real),
        biomass_petiole=PlantSimEngine.Required(Real),
        rank_leaves=PlantSimEngine.Required(Real),
    )
end

function PlantSimEngine.outputs_(::GeometryModel)
    (is_reconstructed=false, geometry_removed=false)
end

PlantSimEngine.variable_contracts_(::GeometryModel) = (
    biomass_leaflets=PlantSimEngine.VariableContract(
        unit=:g_dry_matter,
        basis=:object,
        aggregation=:state,
        extent=:extensive,
    ),
    biomass_rachis=PlantSimEngine.VariableContract(
        unit=:g_dry_matter,
        basis=:object,
        aggregation=:state,
        extent=:extensive,
    ),
    biomass_petiole=PlantSimEngine.VariableContract(
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

    # VPalm parameters:
    vpalm_params = model.vpalm_parameters
    coupling = vpalm_params["xpalm_coupling"]
    rachis_fresh_biomass = fresh_biomass_from_dry_mass(
        status.biomass_rachis,
        coupling["rachis_dry_matter_fraction"],
    )
    leaflet_fresh_biomass = fresh_biomass_from_dry_mass(
        status.biomass_leaflets,
        coupling["leaflets_dry_matter_fraction"],
    )
    petiole_fresh_biomass = fresh_biomass_from_dry_mass(
        status.biomass_petiole,
        coupling["petiole_dry_matter_fraction"],
    )

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

    rachis_reference_length = final_rachis_length(i, 0.0u"kg", vpalm_params)
    leaflet_dimension_scale = coupled_leaf_dimension_scale(
        status.biomass_rachis,
        status.final_potential_area_leaves,
        model.lma_min,
        model.leaflets_biomass_contribution,
        model.rachis_biomass_contribution,
        coupling["dimension_growth_exponent"],
    )
    rachis_realized_length = rachis_reference_length * leaflet_dimension_scale
    coupling_state_missing =
        !hasproperty(leaf, :coupled_rachis_fresh_biomass) ||
        !hasproperty(leaf, :coupled_leaflet_fresh_biomass) ||
        !hasproperty(leaf, :coupled_petiole_fresh_biomass) ||
        !hasproperty(leaf, :leaflet_dimension_scale)
    rank_changed = !hasproperty(leaf, :rank) || leaf.rank != rank_new
    geometry_event =
        !status.is_reconstructed || rank_changed || coupling_state_missing

    # Sample the current simulated biomass at botanical rank transitions. This
    # keeps geometry event-driven (roughly one update per leaf emission) while
    # making each new state depend on XPalm allocation rather than on an
    # inverted VPalm length allometry.
    if geometry_event
        rank_changed, _ = _update_leaf_properties_if_needed!(
            leaf,
            rank_new,
            rachis_realized_length,
            vpalm_params,
            model.rng,
        )
    end
    isnan(leaf.rachis_length) && error("Rachis length: $(leaf.rachis_length), leaf_rank: $(leaf.rank), realized_length: $rachis_realized_length, rachis dry mass: $(status.biomass_rachis)")

    # Internal primordia exist in XPalm's MTG but are not yet visible organs.
    # Delay construction until the leaf enters the sheath; topology then stays
    # fixed while rank-dependent angles and expansion are updated.
    is_visible_leaf_rank(rank_new, vpalm_params) || return nothing

    status.biomass_rachis > 0.0 || return nothing

    if leaflet_dimension_scale <= 0.0
        return nothing
    end

    geometry_event || return nothing
    if !status.is_reconstructed
        status.graph_node_count += 1
        build_leaf(
            unique_mtg_id,
            i,
            leaf,
            rachis_fresh_biomass,
            vpalm_params;
            rachis_final_length=rachis_reference_length,
            leaflet_fresh_biomass=leaflet_fresh_biomass,
            leaflet_dimension_scale=leaflet_dimension_scale,
            rng=model.rng,
        )
    else
        update_leaf!(
            leaf,
            rachis_fresh_biomass,
            vpalm_params;
            leaflet_fresh_biomass=leaflet_fresh_biomass,
            leaflet_dimension_scale=leaflet_dimension_scale,
            rng=model.rng,
            workspace=model.rachis_workspace,
        )
    end

    leaf.coupled_rachis_fresh_biomass = rachis_fresh_biomass
    leaf.coupled_leaflet_fresh_biomass = leaflet_fresh_biomass
    leaf.coupled_petiole_fresh_biomass = petiole_fresh_biomass
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
    if rank_changed || properties_missing
        compute_properties_leaf!(leaf, rank, final_length, parameters, rng)
    elseif length_changed
        leaf.rachis_length = expected_rachis_length
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


function build_leaf(
    unique_mtg_id,
    i,
    leaf,
    biomass_leaf,
    parameters;
    rachis_final_length=leaf.rachis_length,
    leaflet_fresh_biomass=nothing,
    leaflet_dimension_scale=nothing,
    rng,
)
    # Build the petiole
    petiole_node = petiole(
        unique_mtg_id, leaf, i, 5,
        leaf.rachis_length,
        leaf.zenithal_insertion_angle,
        leaf.zenithal_cpoint_angle,
        parameters;
        rng=rng,
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
        rng=rng,
        leaflet_fresh_biomass=leaflet_fresh_biomass,
    )

    # Add the leaflets to the rachis
    leaflets!(
        unique_mtg_id, rachis_node, 5,
        leaf.rank, leaf.rachis_length,
        parameters;
        rachis_final_length=rachis_final_length,
        rng=rng,
    )

    if !isnothing(leaflet_dimension_scale)
        update_leaflet_dimensions!(
            leaf,
            leaflet_dimension_scale,
            parameters,
        )
    end

    # Leaflets created at or beyond the final unfolding rank already have their
    # mature angles, stiffness, and segment profiles. Keep this state on the
    # leaf so later rank transitions can take the mature fast path safely.
    leaf.leaflets_fully_unfolded = leaf.rank >= 2

end


_leaflets_fully_unfolded(leaf) =
    hasproperty(leaf, :leaflets_fully_unfolded) &&
    leaf.leaflets_fully_unfolded === true


function update_leaf!(
    leaf,
    biomass_leaf,
    parameters;
    rng,
    workspace=nothing,
    leaflet_fresh_biomass=nothing,
    leaflet_dimension_scale=nothing,
)
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
        leaflet_fresh_biomass=leaflet_fresh_biomass,
    )

    VPalm.update_leaflet_offsets!(
        rachis,
        leaf.rachis_length,
        parameters["rachis_nb_segments"],
    )

    if !isnothing(leaflet_dimension_scale)
        VPalm.update_leaflet_dimensions!(
            leaf,
            leaflet_dimension_scale,
            parameters,
            # Immature leaves immediately rebuild the same profile below when
            # their unfolding angles are updated. Avoid doing that work twice.
            update_profiles=_leaflets_fully_unfolded(leaf),
        )
    end

    # Leaflet angles and segment profiles reach their final state at rank 2.
    # Use the stored state rather than the current rank for the fast path: an
    # older MTG without this attribute, or a simulation that jumps directly
    # from an immature rank to rank 3+, must still receive one final unfolding
    # update before later transitions can skip the leaflet traversal.
    _leaflets_fully_unfolded(leaf) && return nothing

    traverse!(rachis, symbol=:Leaflet) do leaflet
        VPalm.update_leaflet_angles!(
            leaflet, leaf.rank;
            last_rank_unfolding=last_rank_unfolding,
            xm_intercept=parameters["leaflet_xm_intercept"], xm_slope=parameters["leaflet_xm_slope"],
            ym_intercept=parameters["leaflet_ym_intercept"], ym_slope=parameters["leaflet_ym_slope"]
        )
    end
    leaf.leaflets_fully_unfolded = leaf.rank >= last_rank_unfolding
    return nothing
end
