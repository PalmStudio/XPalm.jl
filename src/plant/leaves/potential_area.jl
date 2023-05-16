struct Potential_AreaModel_BP <: AbstractLeaf_Potential_AreaModel
    phytomer_initiation_age
    age_first_mature_leaf
    leaf_area_first_leaf
    leaf_area_mature_leaf
end

PlantSimEngine.inputs_(::Type{Potential_AreaModel_BP}) = NamedTuple()

PlantSimEngine.outputs_(::Type{Potential_AreaModel_BP}) = (
    potential_area=-Inf,
)

function run!(m::Potential_AreaModel_BP, models, status, meteo, constants, extra=nothing)
    status.potential_area =
        age_relative_var(
            m.phytomer_initiation_age,
            0,
            m.age_first_mature_leaf,
            m.leaf_area_first_leaf,
            m.leaf_area_mature_leaf
        )
end