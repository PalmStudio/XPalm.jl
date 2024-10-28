"""
    LeafCarbonDemandModelPotentialArea(lma_min, respiration_cost, leaflets_biomass_contribution)
    LeafCarbonDemandModelPotentialArea(lma_min= 80.0, respiration_cost=1.44, leaflets_biomass_contribution=0.35)
Carbon demand of the leaf based on the potential leaf area increment of the day.

This model assumes that leaf demand, and hence leaf growth, can be reduced by stresses 
because it only uses the potential area of each day. 

See also [`LeafCarbonDemandModelArea`](@ref).

# Arguments

- `lma_min`: minimum leaf mass area (g m⁻²)
- `respiration_cost`: growth respiration cost (g g⁻¹)
- `leaflets_biomass_contribution`: contribution of the leaflet biomass to the total leaf biomass (including rachis)

# Inputs
- `potential_area`: potential leaf area (m2) 
- `state`: state of the leaf

# Outputs
- `carbon_demand`: daily leaf carbon demand (gC)
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
    if status.state == "Harvested" #! No need for that no? `increment_potential_area` should be 0.0 when the leaf is mature
        status.carbon_demand = zero(eltype(status.carbon_demand))
        return # if it is harvested, no carbon demand
    else
        status.carbon_demand = status.increment_potential_area * (m.lma_min * m.respiration_cost) / m.leaflets_biomass_contribution
    end

    return nothing
end

"""
    LeafCarbonDemandModelArea(lma_min, respiration_cost, leaflets_biomass_contribution)

Carbon demand of the leaf based on the difference between the current leaf area and the 
potential leaf area.

This model assumes that the leaf is always trying to catch its potential growth, so 
leaf demand can increase more than the daily potential to alleviate any previous stress effect.

See also `LeafCarbonDemandModelPotentialArea`.

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

PlantSimEngine.inputs_(::LeafCarbonDemandModelArea) = (potential_area=0.0, leaf_area=-Inf)
PlantSimEngine.outputs_(::LeafCarbonDemandModelArea) = (carbon_demand=0.0,)

function PlantSimEngine.run!(m::LeafCarbonDemandModelArea, models, status, meteo, constants, extra=nothing)
    increment_potential_area = status.potential_area - status.leaf_area
    status.carbon_demand = increment_potential_area * (m.lma_min * m.respiration_cost) / m.leaflets_biomass_contribution
end