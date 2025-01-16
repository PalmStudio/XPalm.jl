"""
    RankLeafPruning(rank)

Function to remove leaf biomass and area when the phytomer has an harvested bunch or when the leaf reaches a treshold rank (below rank of harvested bunches) 

# Arguments
- `rank`: leaf rank treshold below whith the leaf is cutted

# Inputs
- `state`: phytomer state

# Outputs 
- `litter_leaf`: leaf biomass removed from the plantand going to the litter

"""

struct RankLeafPruning{T} <: AbstractLeaf_PruningModel
    rank::T
end

PlantSimEngine.inputs_(::RankLeafPruning) = (rank=-9999, state="undetermined", biomass=-Inf, leaf_area=-Inf, state_phytomers=["undetermined"])
PlantSimEngine.outputs_(::RankLeafPruning) = (litter_leaf=-Inf, pruning_decision="undetermined", is_pruned=false)

# Applied at the leaf scale:
function PlantSimEngine.run!(m::RankLeafPruning, models, status, meteo, constants, extra=nothing)
    status.is_pruned && return # if the leaf is already pruned, no need to compute. Note that we don't use the state of the leaf here
    # because it may be pruned set to "Pruned" by the InfloStateModel, in which case the leaf is not really pruned yet.

    # The rank and state variables are given for the phytomer. We can retrieve the phytomer of the 
    # leaf by using its index. If the phytomer has a higher rank than m.rank or it is harvested, then
    # we put the leaf as pruned and define its biomass as litter.
    if status.rank > m.rank || status.state == "Pruned"
        status.pruning_decision = status.rank > m.rank ? "Pruned at rank" : "Pruned at bunch harvest"
        status.leaf_area = 0.0
        status.litter_leaf = status.biomass
        status.biomass = 0.0
        status.reserve = 0.0
        status.state = "Pruned" # The leaf may not be pruned yet if it has a male inflorescence.
        status.is_pruned = true

        # Get the internode node to check if the phytomer is harvested:
        internode_node = parent(status.node)

        # If the leaf is pruned but the phytomer is not harvested, then we harvest:
        phytomer_node = parent(internode_node)
        phytomer_node[:plantsimengine_status].state = "Harvested"

        # Give the information to the inflorescence if we find one:
        internode_children = MultiScaleTreeGraph.children(internode_node)
        inflo_nodes = filter(x -> MultiScaleTreeGraph.symbol(x) == "Female" || MultiScaleTreeGraph.symbol(x) == "Male", internode_children)
        if length(inflo_nodes) == 1
            inflo_nodes[1][:plantsimengine_status].state = "Harvested"
        end
    end
end