
"""
InternodeCarbonDemandModel(; apparent_density_dry=300000.0, carbon_concentration=0.5, respiration_cost=1.44)

Compute internode carbon demand from potential dimensions

# Arguments

- `apparent_density`: stem apparent density of dry matter (g[dry mass] m⁻³).
- `carbon_concentration`: carbon concentration in the stem (g[C] g[dry mass]⁻¹). 
- `respiration_cost`: repisration cost  (g[sugar].g[carbon mass]-1)

# Notes

The stem apparent density is transformed into a carbon density by multiplying it by the carbon concentration.

# Inputs

- `potential_height`: potential height of the internode (m)
- `potential_radius`: potential radius of the internode (m)

# Outputs

- `potential_volume`: potential volume of the internode (m³)
- `carbon_demand`: daily carbon demand of the internode (g[sugar])

"""
struct InternodeCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    apparent_density::T # In g[C] m-3 here
    respiration_cost::T
end


function InternodeCarbonDemandModel(; apparent_density=300000.0, carbon_concentration=0.5, respiration_cost=1.44)
    InternodeCarbonDemandModel(apparent_density * carbon_concentration, respiration_cost)
end

PlantSimEngine.inputs_(::InternodeCarbonDemandModel) = (
    potential_height=-Inf,
    potential_radius=-Inf,
)
PlantSimEngine.outputs_(::InternodeCarbonDemandModel) = (potential_volume=0.0, carbon_demand=0.0,)

function PlantSimEngine.run!(m::InternodeCarbonDemandModel, models, status, meteo, constants, extra=nothing)
    new_potential_volume = status.potential_height * π * status.potential_radius^2
    increment_potential = (new_potential_volume - status.potential_volume) * m.apparent_density
    status.carbon_demand = increment_potential * m.respiration_cost
    # Note: the respiration cost is in g[sugar].g[carbon mass]-1, so we multiply the potential increment in biomass by it 
    # to get the total carbon demand in g[sugar]
    status.potential_volume = new_potential_volume
end
