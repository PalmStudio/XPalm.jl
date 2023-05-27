"""
    LeafCarbonDemandModel(lma_min, respiration_cost, leaflets_biomass_contribution)

Carbon demand of the leaf based on the potential leaf area increment of the day.

# Arguments

- `lma_min`: minimum leaf mass area (g m⁻²)
- `respiration_cost`: growth respiration cost (g g⁻¹)
- `leaflets_biomass_contribution`: contribution of the leaflet biomass to the total leaf biomass (including rachis)
"""
struct LeafCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    lma_min::T
    respiration_cost::T
    leaflets_biomass_contribution::T
end

PlantSimEngine.inputs_(::LeafCarbonDemandModel) = (potential_area=-Inf,)
PlantSimEngine.outputs_(::LeafCarbonDemandModel) = (carbon_demand=-Inf,)

function PlantSimEngine.run!(m::LeafCarbonDemandModel, models, status, meteo, constants, extra=nothing)
    increment_potential_area = status.potential_area - prev_value(status, :potential_area, default=0.0)
    status.carbon_demand = increment_potential_area * (m.lma_min * m.respiration_cost) / m.leaflets_biomass_contribution
end

# Plant scale:
function PlantSimEngine.run!(m::LeafCarbonDemandModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    @assert mtg.MTG.symbol == "Plant" "The node should be a Plant but is a $(mtg.MTG.symbol)"

    carbon_demand = MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do leaf
        leaf[:models].status[rownumber(status)][:carbon_demand]
    end
    status.carbon_demand = sum(carbon_demand)
end
