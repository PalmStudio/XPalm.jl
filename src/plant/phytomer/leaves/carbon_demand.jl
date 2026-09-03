"""
    LeafCarbonDemandModelPotentialArea(lma_min, respiration_cost, leaflets_biomass_contribution)
    LeafCarbonDemandModelPotentialArea(lma_min=80.0, respiration_cost=1.44, leaflets_biomass_contribution=0.30)
Carbon demand of the leaf based on the potential leaf area increment of the day.

This model assumes that leaf demand, and hence leaf growth, can be reduced by stresses 
because it only uses the potential area of each day. 

See also [`LeafCarbonDemandModelArea`](@ref).

# Arguments

- `lma_min`: minimum leaflet dry mass per unit leaflet area (gDM m⁻²)
- `respiration_cost`: construction cost
  (g CH2O-equivalent allocated gDM⁻¹ produced)
- `leaflets_biomass_contribution`: contribution of leaflet biomass to total leaf
  biomass, including rachis and petiole

# Inputs
- `potential_area`: potential leaf area (m2) 
- `state`: state of the leaf

# Outputs
- `carbon_demand`: daily leaf assimilate demand (g CH2O-equivalent)
"""

struct LeafCarbonDemandModelPotentialArea{T} <: AbstractCarbon_DemandModel
    lma_min::T
    respiration_cost::T
    leaflets_biomass_contribution::T
end

function LeafCarbonDemandModelPotentialArea(
    lma_min,
    respiration_cost,
    leaflets_biomass_contribution,
)
    values = promote(lma_min, respiration_cost, leaflets_biomass_contribution)
    LeafCarbonDemandModelPotentialArea{typeof(first(values))}(values...)
end

# Compatibility with the short-lived API that accepted carbon concentration.
# Construction cost is already expressed per gDM, so this value is not used.
LeafCarbonDemandModelPotentialArea(
    lma_min,
    respiration_cost,
    leaflets_biomass_contribution,
    carbon_concentration,
) = LeafCarbonDemandModelPotentialArea(
    lma_min,
    respiration_cost,
    leaflets_biomass_contribution,
)

LeafCarbonDemandModelPotentialArea(;
    lma_min=80.0,
    respiration_cost=1.44,
    leaflets_biomass_contribution=0.30,
    carbon_concentration=nothing,
) = LeafCarbonDemandModelPotentialArea(
    lma_min,
    respiration_cost,
    leaflets_biomass_contribution,
)

PlantSimEngine.inputs_(::LeafCarbonDemandModelPotentialArea) = (
    increment_potential_area=PlantSimEngine.Required(Real),
    state=PlantSimEngine.Required(Symbol),
)
PlantSimEngine.outputs_(::LeafCarbonDemandModelPotentialArea) = (carbon_demand=0.0,)
PlantSimEngine.variable_contracts_(::LeafCarbonDemandModelPotentialArea) = (
    carbon_demand=_DAILY_CH2O_EQUIVALENT_FLOW,
)

function PlantSimEngine.run!(m::LeafCarbonDemandModelPotentialArea, status, environment, constants, context=nothing)
    if status.state == :pruned #! No need for that no? `increment_potential_area` should be 0.0 when the leaf is mature
        status.carbon_demand = zero(status.carbon_demand)
        return nothing
    else
        status.carbon_demand = status.increment_potential_area *
                               (m.lma_min * m.respiration_cost) /
                               m.leaflets_biomass_contribution
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

- `lma_min`: minimum leaflet dry mass per unit leaflet area (gDM m⁻²)
- `respiration_cost`: construction cost
  (g CH2O-equivalent allocated gDM⁻¹ produced)
- `leaflets_biomass_contribution`: contribution of leaflet biomass to total leaf
  biomass, including rachis and petiole
"""
struct LeafCarbonDemandModelArea{T} <: AbstractCarbon_DemandModel
    lma_min::T
    respiration_cost::T
    leaflets_biomass_contribution::T
end

function LeafCarbonDemandModelArea(lma_min, respiration_cost, leaflets_biomass_contribution)
    values = promote(lma_min, respiration_cost, leaflets_biomass_contribution)
    LeafCarbonDemandModelArea{typeof(first(values))}(values...)
end

# Compatibility with the short-lived API that accepted carbon concentration.
LeafCarbonDemandModelArea(
    lma_min,
    respiration_cost,
    leaflets_biomass_contribution,
    carbon_concentration,
) = LeafCarbonDemandModelArea(
    lma_min,
    respiration_cost,
    leaflets_biomass_contribution,
)

LeafCarbonDemandModelArea(;
    lma_min=80.0,
    respiration_cost=1.44,
    leaflets_biomass_contribution=0.30,
    carbon_concentration=nothing,
) = LeafCarbonDemandModelArea(
    lma_min,
    respiration_cost,
    leaflets_biomass_contribution,
)

PlantSimEngine.inputs_(::LeafCarbonDemandModelArea) = (
    potential_area=PlantSimEngine.Required(Real),
    leaf_area=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::LeafCarbonDemandModelArea) = (carbon_demand=0.0,)
PlantSimEngine.variable_contracts_(::LeafCarbonDemandModelArea) = (
    carbon_demand=_DAILY_CH2O_EQUIVALENT_FLOW,
)

function PlantSimEngine.run!(m::LeafCarbonDemandModelArea, status, environment, constants, context=nothing)
    increment_potential_area = status.potential_area - status.leaf_area
    status.carbon_demand = increment_potential_area *
                           (m.lma_min * m.respiration_cost) /
                           m.leaflets_biomass_contribution
end
