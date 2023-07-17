struct InternodeCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    stem_apparent_density::T
    respiration_cost::T
end


"""
InternodeCarbonDemandModel(stem_apparent_density,respiration_cost)
InternodeCarbonDemandModel(stem_apparent_density=3000.0,respiration_cost=1.44)

Compute internode carbon demand from potential dimensions

# Arguments

- `respiration_cost`: repisration cost  (g g-1)
- `stem_apparent_density`: stem apparent density  (g m-3)

# Example

```jldoctest

```

"""


PlantSimEngine.inputs_(::InternodeCarbonDemandModel) = (
    potential_height=-Inf,
    potential_radius=-Inf,
)
PlantSimEngine.outputs_(::InternodeCarbonDemandModel) = (carbon_demand=-Inf,)

function PlantSimEngine.run!(m::InternodeCarbonDemandModel, models, status, meteo, constants, extra=nothing)
    potential_volume_prev = prev_value(status, :potential_height, default=status.potential_height) * π *
                            prev_value(status, :potential_radius, default=status.potential_radius)^2
    if potential_volume_prev == -Inf
        potential_volume_prev = 0.0
    end
    potential_volume = status.potential_height * π * status.potential_radius^2
    increment_potential = (potential_volume - potential_volume_prev) * m.stem_apparent_density
    status.carbon_demand = increment_potential / m.respiration_cost
end
