
"""
InternodeCarbonDemandModel(stem_apparent_density,respiration_cost)
InternodeCarbonDemandModel(stem_apparent_density=3000.0,respiration_cost=1.44)

Compute internode carbon demand from potential dimensions

# Arguments

- `stem_apparent_density`: stem apparent density  (g m⁻³)
- `respiration_cost`: repisration cost  (g[sugar].g[carbon mass]-1)

# Inputs

- `potential_height`: potential height of the internode (m)
- `potential_radius`: potential radius of the internode (m)

# Outputs

- `potential_volume`: potential volume of the internode (m³)
- `carbon_demand`: daily carbon demand of the internode (g[sugar])

"""
struct InternodeCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    stem_apparent_density::T
    respiration_cost::T
end


PlantSimEngine.inputs_(::InternodeCarbonDemandModel) = (
    potential_height=-Inf,
    potential_radius=-Inf,
)
PlantSimEngine.outputs_(::InternodeCarbonDemandModel) = (potential_volume=0.0, carbon_demand=0.0,)

function PlantSimEngine.run!(m::InternodeCarbonDemandModel, models, status, meteo, constants, extra=nothing)
    new_potential_volume = status.potential_height * π * status.potential_radius^2
    increment_potential = (new_potential_volume - status.potential_volume) * m.stem_apparent_density
    status.carbon_demand = increment_potential * m.respiration_cost
    # Note: the respiration cost is in g[sugar].g[carbon mass]-1, so we multiply the potential increment in biomass by it 
    # to get the total carbon demand in g[sugar]
    status.potential_volume = new_potential_volume
end
