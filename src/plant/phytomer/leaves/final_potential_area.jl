struct FinalPotential_AreaModel{A,L} <: AbstractLeaf_Final_Potential_AreaModel
    age_first_mature_leaf::A
    leaf_area_first_leaf::L
    leaf_area_mature_leaf::L
end

PlantSimEngine.inputs_(::FinalPotential_AreaModel) = (initiation_age=-Inf,)

PlantSimEngine.outputs_(::FinalPotential_AreaModel) = (
    final_potential_area=-Inf, # Potential area of the leaf at full development
    daily_potential_area=-Inf, # Daily potential area (during leaf development)
)

function PlantSimEngine.run!(m::FinalPotential_AreaModel, models, status, meteo, constants, extra=nothing)
    # This is the potential area of the leaf (should be computed once only...)
    status.final_potential_area =
        age_relative_var(
            status.initiation_age,
            0,
            m.age_first_mature_leaf,
            m.leaf_area_first_leaf,
            m.leaf_area_mature_leaf
        )
end

function PlantSimEngine.run!(::FinalPotential_AreaModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    status.potential_area = PlantMeteo.prev_value(status, :potential_area, default=status.potential_area)
end
