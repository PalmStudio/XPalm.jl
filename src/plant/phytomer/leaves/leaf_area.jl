struct LeafAreaModel <: AbstractLeaf_AreaModel end

PlantSimEngine.inputs_(::LeafAreaModel) = NamedTuple()
PlantSimEngine.outputs_(::LeafAreaModel) = (leaf_area=-Inf,)

# Applied at the phytomer scale:
function PlantSimEngine.run!(::LeafAreaModel, models, status, meteo, constants, extra=nothing)
    expansion_rate = status.potential_area - prev_value(status, :potential_area, default=0.0)

    status.leaf_area = status.potential_area
end

# Applied at the plant scale:
function PlantSimEngine.run!(::LeafAreaModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    leaf_area = MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do node
        node[:models].status[rownumber(status)][:leaf_area]
    end

    status.leaf_area = sum(leaf_area)
end