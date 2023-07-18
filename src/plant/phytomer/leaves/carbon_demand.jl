"""
    LeafCarbonDemandModelPotentialArea(lma_min, respiration_cost, leaflets_biomass_contribution)

Carbon demand of the leaf based on the potential leaf area increment of the day.

This model assumes that leaf demand, and hence leaf growth, can be reduced by stresses 
because it only uses the potential area of each day. 

See also [`LeafCarbonDemandModelArea`](@ref).

# Arguments

- `lma_min`: minimum leaf mass area (g m⁻²)
- `respiration_cost`: growth respiration cost (g g⁻¹)
- `leaflets_biomass_contribution`: contribution of the leaflet biomass to the total leaf biomass (including rachis)
"""
struct LeafCarbonDemandModelPotentialArea{T} <: AbstractCarbon_DemandModel
    lma_min::T
    respiration_cost::T
    leaflets_biomass_contribution::T
end

PlantSimEngine.inputs_(::LeafCarbonDemandModelPotentialArea) = (potential_area=-Inf, state="undetermined")
PlantSimEngine.outputs_(::LeafCarbonDemandModelPotentialArea) = (carbon_demand=-Inf,)

function PlantSimEngine.run!(m::LeafCarbonDemandModelPotentialArea, models, status, meteo, constants, extra=nothing)
    if prev_value(status, :state, default="undetermined") == "Harvested"
        status.carbon_demand = zero(eltype(status.carbon_demand))
        return # if it is harvested, no carbon demand
    end
    increment_potential_area = status.potential_area - prev_value(status, :potential_area, default=0.0)
    status.carbon_demand = increment_potential_area * (m.lma_min * m.respiration_cost) / m.leaflets_biomass_contribution
end

# Plant scale:
function PlantSimEngine.run!(::LeafCarbonDemandModelPotentialArea, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    @assert mtg.MTG.symbol == "Plant" "The node should be a Plant but is a $(mtg.MTG.symbol)"

    carbon_demand = Vector{typeof(status.carbon_demand)}()
    MultiScaleTreeGraph.traverse!(mtg, symbol="Leaf") do leaf
        push!(carbon_demand, leaf[:models].status[rownumber(status)][:carbon_demand])
    end
    status.carbon_demand = sum(carbon_demand)
end



"""
    LeafCarbonDemandModelArea(lma_min, respiration_cost, leaflets_biomass_contribution)

Carbon demand of the leaf based on the difference between the current leaf area and the 
potential leaf area.

This model assumes that the leaf is always trying to catch its potential growth, so 
leaf demand can increase more than the daily potential to alleviate any previous stress effect.

See also [`LeafCarbonDemandModelPotentialArea`](@ref).

# Arguments

- `lma_min`: minimum leaf mass area (g m⁻²)
- `respiration_cost`: growth respiration cost (g g⁻¹)
- `leaflets_biomass_contribution`: contribution of the leaflet biomass to the total leaf biomass (including rachis)
"""
struct LeafCarbonDemandModelArea{T} <: AbstractCarbon_DemandModel
    lma_min::T
    respiration_cost::T
    leaflets_biomass_contribution::T
end

PlantSimEngine.inputs_(::LeafCarbonDemandModelArea) = (potential_area=-Inf,)
PlantSimEngine.outputs_(::LeafCarbonDemandModelArea) = (carbon_demand=-Inf,)

function PlantSimEngine.run!(m::LeafCarbonDemandModelArea, models, status, meteo, constants, extra=nothing)
    increment_potential_area = status.potential_area - prev_value(status, :leaf_area, default=0.0)
    status.carbon_demand = increment_potential_area * (m.lma_min * m.respiration_cost) / m.leaflets_biomass_contribution
end
