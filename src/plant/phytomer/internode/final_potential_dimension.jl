struct FinalPotentialInternodeDimensionModel{A,L} <: AbstractInternode_Final_Potential_DimensionsModel
    age_max_height::A
    age_max_radius::A
    min_height::L
    min_radius::L
    max_height::L
    max_radius::L
end

PlantSimEngine.inputs_(::FinalPotentialInternodeDimensionModel) = (initiation_age=-Inf,)

PlantSimEngine.outputs_(::FinalPotentialInternodeDimensionModel) = (
    final_potential_height=-Inf,
    final_potential_radius=-Inf,
)

function PlantSimEngine.run!(m::FinalPotentialInternodeDimensionModel, models, status, meteo, constants, extra=nothing)
    # This is the potential area of the leaf (should be computed once only...)
    status.final_potential_height =
        age_relative_var(
            status.initiation_age,
            0,
            m.age_max_height,
            m.min_height,
            m.max_height
        )

    status.final_potential_radius =
        age_relative_var(
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
