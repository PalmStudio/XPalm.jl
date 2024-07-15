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

PlantSimEngine.inputs_(::LeafCarbonDemandModelPotentialArea) = (increment_potential_area=-Inf, state="undetermined")
PlantSimEngine.outputs_(::LeafCarbonDemandModelPotentialArea) = (carbon_demand=0.0,)

function PlantSimEngine.run!(m::LeafCarbonDemandModelPotentialArea, models, status, meteo, constants, extra=nothing)
    # Get the index of the leaf in the organ list (we added the organ index in the organ list as the index of the MTG):
    if status.state == "Harvested" #! No no need for that no? `increment_potential_area` should be 0.0 when the leaf is mature
        status.carbon_demand = zero(eltype(status.carbon_demand))
        return # if it is harvested, no carbon demand
    else
        status.carbon_demand = status.increment_potential_area * (m.lma_min * m.respiration_cost) / m.leaflets_biomass_contribution
    end

    return nothing
end

#? This model is not used anymore, it is directly computed in `OrgansCarbonAllocationModel`.
# struct PlantTotalLeafCarbonDemand <: AbstractCarbon_DemandModel end
# PlantSimEngine.inputs_(::PlantTotalLeafCarbonDemand) = (carbon_demand=[-Inf],)
# PlantSimEngine.outputs_(::PlantTotalLeafCarbonDemand) = (plant_total_leaf_carbon_demand=0.0,)
# function PlantSimEngine.run!(m::PlantTotalLeafCarbonDemand, models, status, meteo, constants, extra=nothing)
#     # @assert status.node.MTG.symbol == "Plant" "The node should be a Plant but is a $(status.node.MTG.symbol)"
#     status.plant_total_leaf_carbon_demand = sum(status.carbon_demand)
# end

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

PlantSimEngine.inputs_(::LeafCarbonDemandModelArea) = (potential_area=-Inf, leaf_area=-Inf)
PlantSimEngine.outputs_(::LeafCarbonDemandModelArea) = (carbon_demand=0.0,)

function PlantSimEngine.run!(m::LeafCarbonDemandModelArea, models, status, meteo, constants, extra=nothing)
    increment_potential_area = status.potential_area - status.leaf_area
    status.carbon_demand = increment_potential_area * (m.lma_min * m.respiration_cost) / m.leaflets_biomass_contribution
end