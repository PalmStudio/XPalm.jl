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

struct RankLeafPruning <: AbstractLeaf_PruningModel
    rank
end

PlantSimEngine.inputs_(::RankLeafPruning) = (rank=-9999, state="undetermined",)
PlantSimEngine.outputs_(::RankLeafPruning) = (litter_leaf=-Inf,)

# Applied at the phytomer scale:
function PlantSimEngine.run!(m::RankLeafPruning, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    if status.rank > m.rank || status.state == "Harvested"
        leaf = mtg[1][1]
        leaf.type.state = Pruned()
        leaf[:models].status[rownumber(status)].leaf_area = 0.0

        status.litter_leaf = leaf[:models].status[rownumber(status)].biomass
        leaf[:models].status[rownumber(status)].biomass = 0.0
    end
end