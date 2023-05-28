struct PotentialInternodeDimensionModel{T} <: AbstractInternode_Potential_DimensionsModel
    inflexion_point_height::T
    slope_height::T
    inflexion_point_radius::T
    slope_radius::T
end

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
    # This is the daily potential area of the leaf (should be computed once only...)

    status.potential_height =
        status.final_potential_height / (1.0 + exp(-(status.TT_since_init - m.inflexion_point_height) / m.slope_height))

    status.potential_radius =
        status.final_potential_radius / (1.0 + exp(-(status.TT_since_init - m.inflexion_point_radius) / m.slope_radius))
end