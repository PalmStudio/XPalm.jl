struct RankLeafPruning <: AbstractLeaf_PruningModel
    rank
end

PlantSimEngine.inputs_(::RankLeafPruning) = (rank=-9999,)
PlantSimEngine.outputs_(::RankLeafPruning) = NamedTuple()

function PlantSimEngine.run!(m::RankLeafPruning, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    if status.rank > m.rank
        leaf = mtg[1][1]
        leaf.type.status = Pruned()
        leaf[:models].status[rownumber(status)].leaf_area = 0.0
    end
end