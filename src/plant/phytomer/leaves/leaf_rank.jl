struct LeafRankModel <: AbstractLeaf_RankModel end

PlantSimEngine.inputs_(::LeafRankModel) = NamedTuple()
PlantSimEngine.outputs_(::LeafRankModel) = (rank=-9999,)

function PlantSimEngine.run!(::LeafRankModel, models, status, meteo, constants, extra=nothing)
    status.rank = prev_value(status, :rank, default=-9999)
end

function PlantSimEngine.run!(::LeafRankModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    @assert mtg.MTG.symbol == "Leaf"
    phytomer = parent(parent(mtg))
    @assert phytomer.MTG.symbol == "Phytomer" "mtg.MTG.symbol should be Phytomer, it is $(mtg.MTG.symbol)"
    row_number = PlantMeteo.rownumber(status)
    phytomer[:models].status[row_number].rank = 1
    increase_rank_parent(phytomer, row_number)
end

function increase_rank_parent(node, row_number)
    parent = node.parent
    if parent.MTG.symbol == "Phytomer"
        parent[:models].status[row_number].rank += 1
        increase_rank_parent(parent, row_number)
    else
        return
    end
end