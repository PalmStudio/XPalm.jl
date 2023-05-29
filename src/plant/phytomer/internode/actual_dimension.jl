struct InternodeDimensionModel{T} <: AbstractInternode_DimensionsModel
    stem_apparent_density::T
end


PlantSimEngine.inputs_(::InternodeDimensionModel) = (
    potential_height=-Inf,
    potential_radius=-Inf,
)
PlantSimEngine.outputs_(::InternodeDimensionModel) = (
    height=-Inf,
    radius=-Inf,
)

# Applied at the phytomer scale:
function PlantSimEngine.run!(m::InternodeDimensionModel, models, status, meteo, constants, extra=nothing)
    height_to_width_ratio = status.potential_height / status.potential_radius
    actual_volume = status.biomass / m.stem_apparent_density
    status.height = (actual_volume * (height_to_width_ratio^2) / π)^(1 / 3)
    status.radius = status.height / height_to_width_ratio
end