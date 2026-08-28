PlantSimEngine.@process "geometry" verbose = false

"""
    GeometryModel(;vpalm_parameters, rng=Random.MersenneTwister())

A PlantSimEngine model that builds the 3D geometry for a leaf, including the petiole, rachis, and leaflets.
This model operates at the phytomer scale and modifies the MTG directly.

# Arguments

- `vpalm_parameters::Dict{String,Any}`: VPalm model parameters.
- `rng::Random.AbstractRNG`: Random number generator for stochastic processes.

# Inputs

- `state`: Phenological state of the target Phytomer.
- `height_internodes`: Height of the Internode below the target Phytomer.
- `radius_internodes`: Radius of the Internode below the target Phytomer.
- `biomass_leaves`: Biomass of the Leaf below the target Phytomer.
- `rank_leaves`: Rank of the Leaf below the target Phytomer.

# Outputs

This model has no outputs as it modifies the MTG directly by adding geometric properties and child nodes.

# Notes

The model requires access to the VPalm parameters via the parameters dictionary under the "vpalm" key.
"""
struct GeometryModel{I,T,D<:AbstractDict{String}} <: AbstractGeometryModel
    graph_node_count_init::I
    vpalm_parameters::D
    rng::T
end

function GeometryModel(; mtg::Node, vpalm_parameters, rng)
    GeometryModel(length(mtg), vpalm_parameters, rng)
end

function PlantSimEngine.inputs_(m::GeometryModel)
    (
        graph_node_count=PlantSimEngine.Default(m.graph_node_count_init),
        state=PlantSimEngine.Required(Symbol),
        height_internodes=PlantSimEngine.Required(AbstractVector),
        radius_internodes=PlantSimEngine.Required(AbstractVector),
        biomass_leaves=PlantSimEngine.Required(AbstractVector),
        rank_leaves=PlantSimEngine.Required(AbstractVector),
    )
end

function PlantSimEngine.outputs_(::GeometryModel)
    (is_reconstructed=false,)
end

"""
    run!(model, status, environment, constants, context)

Builds the 3D geometry for a leaf by adding internode properties and creating child nodes for
petiole, rachis, and leaflets.

# Arguments

- `model::GeometryModel`: The leaf geometry model
- `status`: The status of the model with inputs (state, height, radius, biomass, rank)
- `environment`: Meteorology structure (not used by this model)
- `constants`: Physical constants (not used by this model)
- `context`: PlantSimEngine runtime context used to resolve the source MTG node.

# Notes

PlantSimEngine owns runtime status in its object registry. The declared
Phytomer, Internode, and Leaf inputs carry the scientific values used for
reconstruction; the source MTG is used only for topology and geometry.
"""
function PlantSimEngine.run!(model::GeometryModel, status, environment, constants, context)
    phytomer = PlantSimEngine.source_node(context)
    # Get internode and leaf nodes:
    internode = phytomer[1]
    leaf = internode[1]

    if status.state == :pruned
        leaf.is_alive = false # This is used in the reconstruction for putting snags
        return nothing
    end

    # Get the unique MTG ID
    unique_mtg_id = PlantSimEngine.refvalue(status, :graph_node_count)

    symbol(leaf) != :Leaf && error("Expected leaf node, got $(symbol(leaf))")

    biomass_leaf_value = only(status.biomass_leaves)
    biomass_leaf_value <= 0.0 && return nothing # No biomass, no geometry
    biomass_leaf = uconvert(u"kg", biomass_leaf_value * u"g")
    # VPalm parameters:
    vpalm_params = model.vpalm_parameters

    # Set internode properties
    i = index(internode)
    internode.width = only(status.radius_internodes) * 2.0u"m"
    internode.length = only(status.height_internodes) * u"m"
    internode.rank = only(status.rank_leaves)
    internode.Orthotropy = 0.05u"°"
    internode.XEuler = phyllotactic_angle(
        vpalm_params["phyllotactic_angle_mean"],
        vpalm_params["phyllotactic_angle_sd"];
        rng=model.rng
    )

    # Set leaf properties
    rank_new = only(status.rank_leaves)
    update_in_rank = leaf.rank != rank_new #! we update the leaves geometry only if the rank has changed
    leaf.rank = rank_new
    leaf.is_alive = true

    current_length = rachis_length_from_biomass(
        biomass_leaf,
        vpalm_params["leaf_length_intercept"],
        vpalm_params["leaf_length_slope"]
    )

    # Compute leaf properties
    compute_properties_leaf!(leaf, rank_new, current_length, vpalm_params, model.rng)
    isnan(leaf.rachis_length) && error("Rachis length: $(leaf.rachis_length), leaf_rank: $(leaf.rank), final_length: $current_length, biomass: $biomass_leaf")
    if !status.is_reconstructed
        status.graph_node_count += 1
        build_leaf(unique_mtg_id, i, leaf, biomass_leaf, vpalm_params; rng=model.rng)
    elseif update_in_rank
        update_leaf!(leaf, biomass_leaf, vpalm_params; rng=model.rng)
    end

    status.is_reconstructed = true

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


function update_leaf!(leaf, biomass_leaf, parameters; rng)
    petiole = leaf[1]
    petiole.zenithal_insertion_angle = 90.0u"°" - leaf.zenithal_insertion_angle
    petiole.zenithal_cpoint_angle = 90.0u"°" - leaf.zenithal_cpoint_angle
    petiole.section_insertion_angle = (petiole.zenithal_cpoint_angle - petiole.zenithal_insertion_angle) / parameters["petiole_nb_segments"]
    # Rebuild the petiole sections:
    VPalm.update_petiole_angles!(petiole)
    rachis = petiole[2]

    VPalm.update_rachis_angles!(rachis, leaf.rank, leaf.rachis_length, petiole.height_cpoint, petiole.width_cpoint, leaf.zenithal_cpoint_angle, biomass_leaf, parameters; rng)

    traverse!(rachis, symbol=:Leaflet) do leaflet
        VPalm.update_leaflet_angles!(
            leaflet, leaf.rank;
            last_rank_unfolding=2,
            xm_intercept=parameters["leaflet_xm_intercept"], xm_slope=parameters["leaflet_xm_slope"],
            ym_intercept=parameters["leaflet_ym_intercept"], ym_slope=parameters["leaflet_ym_slope"]
        )
    end
end
