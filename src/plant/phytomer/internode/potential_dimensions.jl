struct PotentialInternodeDimensionModel{T} <: AbstractInternode_Potential_DimensionsModel
    inflexion_point_height::T
    slope_height::T
    inflexion_point_radius::T
    slope_radius::T
end

"""
PotentialInternodeDimensionModel(inflexion_point_height,slope_height,inflexion_point_radius,slope_radius)
PotentialInternodeDimensionModel(inflexion_point_height=900.0,slope_height=150.0,inflexion_point_radius=900.0,slope_radius=150.0)


Compute internode potential dimensions (height and radius) from the biomass, with the proportions given by potential dimensions( potential_height and potential_radius)

# Arguments

-`inflexion_point_height`: age when increase in height is maximal (days)
- `slope_height`: daily increment in height at inflexion_point_height (cm. days-1)
- `inflexion_point_radius`: age when increase in radius is maximal (days)
- `slope_radius`:daily increment in radius at inflexion_point_height (cm. days-1)

# Example

```jldoctest

```

"""

PlantSimEngine.inputs_(::PotentialInternodeDimensionModel) = (
    TT_since_init=-Inf,
    final_potential_height=-Inf,
    final_potential_radius=-Inf,
)

PlantSimEngine.outputs_(::PotentialInternodeDimensionModel) = (
    potential_height=-Inf,
    potential_radius=-Inf,
)

function PlantSimEngine.run!(m::PotentialInternodeDimensionModel, models, status, meteo, constants, extra=nothing)

    status.potential_height =
        status.final_potential_height / (1.0 + exp(-(status.TT_since_init - m.inflexion_point_height) / m.slope_height))

    status.potential_radius =
        status.final_potential_radius / (1.0 + exp(-(status.TT_since_init - m.inflexion_point_radius) / m.slope_radius))
end