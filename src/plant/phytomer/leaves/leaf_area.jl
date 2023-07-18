"""
LeafAreaModel(lma_min, leaflets_biomass_contribution)
LeafAreaModel(lma_min=  80.0, leaflets_biomass_contribution=0.35)

Computes leaf area from the leaf biomass

# Arguments

- `lma_min`: minimal leaf mass area (when there is no reserve in leaf)
- `leaflets_biomass_contribution`: ratio of leaflets biomass to the  total leaf biomass (including rachis and petiole) ([0,1])


# Inputs
- `biomass`: leaf biomass (g)

# Outputs

- `leaf_area`: leaf area (m2)

"""
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