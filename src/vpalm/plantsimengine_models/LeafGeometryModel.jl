PlantSimEngine.@process "geometry" verbose = false

"""
    LeafGeometryModel(;vpalm_parameters, rng=Random.MersenneTwister())

A PlantSimEngine model that builds the 3D geometry for a leaf, including the petiole, rachis, and leaflets.
This model operates at the phytomer scale and modifies the MTG directly.

# Arguments

- `vpalm_parameters::Dict{String,Any}`: VPalm model parameters.
- `rng::Random.AbstractRNG`: Random number generator for stochastic processes.

# Inputs

- `height_internodes`: Internode height (from plantsimengine_status)
- `radius_internodes`: Internode radius (from plantsimengine_status)  
- `biomass_leaves`: Leaf biomass (from plantsimengine_status)
- `rank_leaves`: Leaf rank (from plantsimengine_status)

# Outputs

This model has no outputs as it modifies the MTG directly by adding geometric properties and child nodes.

# Notes

The model requires access to the VPalm parameters via the parameters dictionary under the "vpalm" key.
"""
struct LeafGeometryModel{T,D<:AbstractDict{String}} <: AbstractGeometryModel
    vpalm_parameters::D
    rng::T
end

LeafGeometryModel(; vpalm_parameters, rng=Random.MersenneTwister(1234)) = LeafGeometryModel(vpalm_parameters, rng)

function PlantSimEngine.inputs_(::LeafGeometryModel)
    (
        height_internodes=-Inf, radius_internodes=-Inf, # From the internode scale
        biomass_leaves=-Inf, rank_leaves=-Inf # From the leaf scale
    )
end
#! Note: we artificially declare those inputs as multiscale to be sure that this model is run after the internode and leaf scale models, 
#! but we don't use those inputs from the status, instead we get them by traversing the mtg.
#! update this code when https://github.com/VirtualPlantLab/PlantSimEngine.jl/issues/140 is resolved.

function PlantSimEngine.outputs_(::LeafGeometryModel)
    (is_reconstructed=false,)
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:LeafGeometryModel}) = PlantSimEngine.IsObjectDependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:LeafGeometryModel}) = PlantSimEngine.IsTimeStepIndependent()

"""
    run!(model, models, status, meteo, constants, node)

Builds the 3D geometry for a leaf by adding internode properties and creating child nodes for
petiole, rachis, and leaflets.

# Arguments

- `model::LeafGeometryModel`: The leaf geometry model
- `models`: A `ModelList` struct holding the parameters for the model
- `status`: The status of the model with inputs (height, radius, biomass, rank)
- `meteo`: Meteorology structure (not used by this model)
- `constants`: Physical constants (not used by this model)
- `node`: MTG node of the phytomer

# Notes

The model expects `node` to be the phytomer MTG node and accesses VPalm parameters from `model.vpalm_parameters`.
"""
function PlantSimEngine.run!(model::LeafGeometryModel, models, status, meteo, constants, extra)
    status.state == "Pruned" && return nothing # reconstruct the leaf geometry only if it's not Pruned

    # extract the phytomer from the node
    phytomer = status.node

    # Get the plant from the phytomer to find unique MTG ID
    unique_mtg_id = PlantSimEngine.refvalue(status, :graph_node_count)

    # Get internode and leaf nodes
    internode = phytomer[1]
    leaf = internode[1]

    # VPalm parameters:
    vpalm_params = model.vpalm_parameters

    # Set internode properties
    i = index(internode)
    internode.width = internode.plantsimengine_status.radius * 2.0u"m"
    internode.length = internode.plantsimengine_status.height
    internode.rank = leaf.plantsimengine_status.rank
    internode.Orthotropy = 0.05u"°"
    internode.XEuler = phyllotactic_angle(
        vpalm_params["phyllotactic_angle_mean"],
        vpalm_params["phyllotactic_angle_sd"];
        rng=model.rng
    )

    # Set leaf properties
    rank_new = leaf.plantsimengine_status.rank
    update_in_rank = leaf.rank != rank_new #! we update the leaves geometry only if the rank has changed
    leaf.rank = rank_new
    leaf.is_alive = true

    # Convert biomass and calculate rachis length
    biomass_leaf = uconvert(u"kg", leaf.plantsimengine_status.biomass * u"g")
    current_length = rachis_length_from_biomass(
        biomass_leaf,
        vpalm_params["leaf_length_intercept"],
        vpalm_params["leaf_length_slope"]
    )

    # Compute leaf properties
    compute_properties_leaf!(leaf, leaf.plantsimengine_status.rank, current_length, vpalm_params, model.rng)
    isnan(leaf.rachis_length) && error("Rachis length: $(leaf.rachis_length), leaf_rank: $(leaf.rank), final_length: $current_length, biomass: $biomass_leaf")
    # @show current_length leaf.plantsimengine_status.rank leaf.plantsimengine_status.biomass biomass_leaf
    if !status.is_reconstructed
        status.graph_node_count += 1
        println("$(meteo.date): Building leaf geometry for unique_mtg_id: $(unique_mtg_id[]), index: $i")
        build_leaf(unique_mtg_id, i, leaf, biomass_leaf, vpalm_params; rng=model.rng)
    elseif update_in_rank
        println("$(meteo.date): Updating leaf geometry for unique_mtg_id: $(unique_mtg_id[]), index: $i")
        update_leaf!(leaf, biomass_leaf, vpalm_params; unique_mtg_id=unique_mtg_id, rng=model.rng)
    end

    status.is_reconstructed = true

    return nothing
end


function build_leaf(unique_mtg_id, i, leaf, biomass_leaf, parameters; rng=Random.MersenneTwister(1234))
    # Build the petiole
    petiole_node = petiole(
        unique_mtg_id, i, 5,
        leaf.rachis_length,
        leaf.zenithal_insertion_angle,
        leaf.zenithal_cpoint_angle,
        parameters;
        rng=rng
    )
    addchild!(leaf, petiole_node)

    # Build the rachis
    rachis_node = rachis(
        unique_mtg_id, i, 5, leaf.plantsimengine_status.rank,
        leaf.rachis_length,
        petiole_node.height_cpoint,
        petiole_node.width_cpoint,
        leaf.zenithal_cpoint_angle,
        biomass_leaf,
        parameters;
        rng=rng
    )
    addchild!(petiole_node, rachis_node)

    # Add the leaflets to the rachis
    leaflets!(
        unique_mtg_id, rachis_node, 5,
        leaf.rank, leaf.rachis_length,
        parameters;
        rng=rng
    )

end


function update_leaf!(leaf, biomass_leaf, parameters; unique_mtg_id=Ref(new_id(leaf)), rng)
    petiole = leaf[1]
    petiole.zenithal_insertion_angle = 90.0u"°" - leaf.zenithal_insertion_angle
    petiole.zenithal_cpoint_angle = 90.0u"°" - leaf.zenithal_cpoint_angle
    petiole.section_insertion_angle = (petiole.zenithal_cpoint_angle - petiole.zenithal_insertion_angle) / parameters["petiole_nb_segments"]
    # Rebuild the petiole sections:
    VPalm.update_petiole_angles!(petiole)
    rachis = petiole[2]

    VPalm.update_rachis_angles!(rachis, leaf.rank, leaf.rachis_length, petiole.height_cpoint, petiole.width_cpoint, leaf.zenithal_cpoint_angle, biomass_leaf, parameters; rng)

    traverse!(rachis, symbol="Leaflet") do leaflet
        VPalm.update_leaflet_angles!(
            leaflet, leaf.rank;
            last_rank_unfolding=2, unique_mtg_id=unique_mtg_id,
            xm_intercept=parameters["leaflet_xm_intercept"], xm_slope=parameters["leaflet_xm_slope"],
            ym_intercept=parameters["leaflet_ym_intercept"], ym_slope=parameters["leaflet_ym_slope"]
        )
    end
end