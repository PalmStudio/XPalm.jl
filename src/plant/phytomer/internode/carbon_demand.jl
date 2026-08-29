
"""
InternodeCarbonDemandModel(; apparent_density=300000.0, respiration_cost=1.44)

Compute internode carbon demand from potential dimensions

# Arguments

- `apparent_density`: stem apparent density of dry matter (gDM m⁻³)
- `respiration_cost`: construction cost
  (g CH2O-equivalent allocated gDM⁻¹ produced)

# Inputs

- `potential_height`: potential height of the internode (m)
- `potential_radius`: potential radius of the internode (m)

# Outputs

- `potential_volume`: potential volume of the internode (m³)
- `carbon_demand`: daily assimilate demand of the internode
  (g CH2O-equivalent)

"""
struct InternodeCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    apparent_density::T # gDM m⁻³
    respiration_cost::T
end

function InternodeCarbonDemandModel(;
    apparent_density=300000.0,
    respiration_cost=1.44,
    carbon_concentration=nothing,
)
    values = promote(apparent_density, respiration_cost)
    InternodeCarbonDemandModel{typeof(first(values))}(values...)
end

PlantSimEngine.inputs_(::InternodeCarbonDemandModel) = (
    potential_height=PlantSimEngine.Required(Real),
    potential_radius=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::InternodeCarbonDemandModel) = (potential_volume=0.0, carbon_demand=0.0,)
PlantSimEngine.variable_contracts_(::InternodeCarbonDemandModel) = (
    carbon_demand=_DAILY_CH2O_EQUIVALENT_FLOW,
)

function PlantSimEngine.run!(m::InternodeCarbonDemandModel, status, environment, constants, context=nothing)
    new_potential_volume = status.potential_height * π * status.potential_radius^2
    increment_potential = (new_potential_volume - status.potential_volume) * m.apparent_density
    status.carbon_demand = increment_potential * m.respiration_cost
    status.potential_volume = new_potential_volume
end
