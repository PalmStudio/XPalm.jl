struct LeafAreaModel{T} <: AbstractLeaf_AreaModel
    lma_min::T
    leaflets_biomass_contribution::T
end

PlantSimEngine.inputs_(::LeafAreaModel) = (biomass=-Inf,)
PlantSimEngine.outputs_(::LeafAreaModel) = (leaf_area=-Inf,)

# Applied at the phytomer scale:
function PlantSimEngine.run!(m::LeafAreaModel, models, status, meteo, constants, extra=nothing)
    status.leaf_area = status.biomass * m.leaflets_biomass_contribution / m.lma_min
end

# Applied at the plant scale:
function PlantSimEngine.run!(::LeafAreaModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    leaf_area = MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do node
        node[:models].status[rownumber(status)][:leaf_area]
    end

    status.leaf_area = sum(leaf_area)
end