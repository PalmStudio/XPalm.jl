struct InternodeDimensionModel{T} <: AbstractInternode_DimensionsModel
    apparent_density::T
end

InternodeDimensionModel(; apparent_density=300000.0) = InternodeDimensionModel(apparent_density)

"""
InternodeDimensionModel(;apparent_density=300000.0)

Compute internode dimensions (height and radius) from the biomass, with the proportions given by potential dimensions (`potential_height` and `potential_radius`)

# Arguments
- `apparent_density`: dry-matter apparent density (gDM m⁻³)

# Inputs

- `potential_height`: potential height of the internode (m)
- `potential_radius`: potential radius of the internode (m)
- `biomass`: structural dry mass of the internode (gDM)

# Outputs

- `height`: actual height of the internode (m)
- `radius`: actual radius of the internode (m)
"""


PlantSimEngine.inputs_(::InternodeDimensionModel) = (
    potential_height=PlantSimEngine.Required(Real),
    potential_radius=PlantSimEngine.Required(Real),
    biomass=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::InternodeDimensionModel) = (
    height=-Inf,
    radius=-Inf,
)
PlantSimEngine.variable_contracts_(::InternodeDimensionModel) = (
    biomass=_STRUCTURAL_DRY_MASS,
)

# Applied at the phytomer scale:
function PlantSimEngine.run!(m::InternodeDimensionModel, status, environment, constants, context=nothing)
    if status.potential_radius <= 0.0 || status.potential_height <= 0.0 || status.biomass <= 0.0
        status.height = 0.0
        status.radius = 0.0
    else
        actual_volume = status.biomass / m.apparent_density
        height_to_width_ratio = status.potential_height / status.potential_radius
        status.height = (actual_volume * (height_to_width_ratio^2) / π)^(1.0 / 3.0)
        status.radius = status.height / height_to_width_ratio
    end
end
