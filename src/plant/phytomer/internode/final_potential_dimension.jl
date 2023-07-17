struct FinalPotentialInternodeDimensionModel{A,L} <: AbstractInternode_Final_Potential_DimensionsModel
    age_max_height::A
    age_max_radius::A
    min_height::L
    min_radius::L
    max_height::L
    max_radius::L
end


"""
FinalPotentialInternodeDimensionModel(age_max_height,age_max_radius,min_height,min_radius,max_height,max_radius)
FinalPotentialInternodeDimensionModel(age_max_height= 8 * 365,age_max_radius= 8 * 365,min_height=2e-3,min_radius=2e-3,max_height=0.03,max_radius=0.30)


Compute final potential height and radius of internode according to plant age at internode initiation

# Arguments

- `age_max_height`: plant age at which the height is at the maximum value max_height (ages above this age will have `max_height`)
- `age_max_radius`: the age at which the radius is at the maximum value max_radius (ages above this age will have `max_radius`)
- `min_height`: first internode height (at age =0)
- `min_radius`:first internode radius (at age =0)
- `max_height`: maximum value of internode height
- `max_radius`: maximum value of internode radius

# outputs
final_potential_radius
final_potential_height 

# Example

```jldoctest

```

"""


PlantSimEngine.inputs_(::FinalPotentialInternodeDimensionModel) = (initiation_age=-Inf,)

PlantSimEngine.outputs_(::FinalPotentialInternodeDimensionModel) = (
    final_potential_height=-Inf,
    final_potential_radius=-Inf,
)

function PlantSimEngine.run!(m::FinalPotentialInternodeDimensionModel, models, status, meteo, constants, extra=nothing)
    # This is the potential area of the leaf (should be computed once only...)
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
end

function PlantSimEngine.run!(::FinalPotentialInternodeDimensionModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    status.final_potential_height = prev_value(status, :final_potential_height, default=status.final_potential_height)
    status.final_potential_radius = prev_value(status, :final_potential_radius, default=status.final_potential_radius)
end
