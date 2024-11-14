struct FinalPotentialInternodeDimensionModel{A,L} <: AbstractInternode_Final_Potential_DimensionsModel
    age_max_height::A
    age_max_radius::A
    min_height::L
    min_radius::L
    max_height::L
    max_radius::L
end


function FinalPotentialInternodeDimensionModel(age_max_height=8 * 365, age_max_radius=8 * 365, min_height=2e-3, min_radius=2e-3, max_height=0.03, max_radius=0.30)
    FinalPotentialInternodeDimensionModel(age_max_height, age_max_radius, min_height, min_radius, max_height, max_radius)
end

"""
FinalPotentialInternodeDimensionModel(age_max_height,age_max_radius,min_height,min_radius,max_height,max_radius)
FinalPotentialInternodeDimensionModel(age_max_height= 8 * 365,age_max_radius= 8 * 365,min_height=2e-3,min_radius=2e-3,max_height=0.03,max_radius=0.30)


Compute final potential height and radius of internode according to plant age at internode initiation

# Arguments

- `age_max_height`: plant age at which the height is at the maximum value max_height (ages above this age will have `max_height`)
- `age_max_radius`: the age at which the radius is at the maximum value max_radius (ages above this age will have `max_radius`)
- `min_height`: first internode height (at age=0, m)
- `min_radius`:first internode radius (at age=0, m)
- `max_height`: maximum value of internode height (m)
- `max_radius`: maximum value of internode radius (m)

# Inputs

- `initiation_age`: plant age at internode initiation (days)

# Outputs

- `final_potential_radius`: potential radius of the internode once fully developped (m)
- `final_potential_height`: potential height of the internode once fully developped (m)
"""


PlantSimEngine.inputs_(::FinalPotentialInternodeDimensionModel) = (initiation_age=-9999,)

PlantSimEngine.outputs_(::FinalPotentialInternodeDimensionModel) = (
    final_potential_height=-Inf,
    final_potential_radius=-Inf,
)

function PlantSimEngine.run!(m::FinalPotentialInternodeDimensionModel, models, status, meteo, constants, extra=nothing)
    status.final_potential_height =
        age_relative_value(
            status.initiation_age,
            0,
            m.age_max_height,
            m.min_height,
            m.max_height
        )

    status.final_potential_radius =
        age_relative_value(
            status.initiation_age,
            0,
            m.age_max_radius,
            m.min_radius,
            m.max_radius
        )

    return nothing
end