"""
FinalPotentialAreaModel(age_first_mature_leaf,leaf_area_first_leaf,leaf_area_mature_leaf)
FinalPotentialAreaModel(age_first_mature_leaf= 8 * 365,    leaf_area_first_leaf
= 0.0015,leaf_area_mature_leaf=12.0)


Compute final potential area of the leaf according to plant age at leaf initiation

# Arguments

- `age_first_mature_leaf`: plant age at which leaf area reach its maximum potential value (days)
- `leaf_area_first_leaf`: area of the first leaf (age=0)
- `leaf_area_mature_leaf`: area of the mature leaf (when age>age_first_mature_leaf)


# outputs
final_potential_area: potential area of the leaf at emmission (rank1 and above) 

# Example

```jldoctest

```

"""

struct FinalPotentialAreaModel{A,L} <: AbstractLeaf_Final_Potential_AreaModel
    age_first_mature_leaf::A
    leaf_area_first_leaf::L
    leaf_area_mature_leaf::L
end


PlantSimEngine.inputs_(::FinalPotentialAreaModel) = (initiation_age=-Inf,)

PlantSimEngine.outputs_(::FinalPotentialAreaModel) = (
    final_potential_area=-Inf, # Potential area of the leaf at full development
)

function PlantSimEngine.run!(m::FinalPotentialAreaModel, models, status, meteo, constants, extra=nothing)
    # This is the potential area of the leaf (should be computed once only...)
    status.final_potential_area =
        age_relative_value(
            status.initiation_age,
            0,
            m.age_first_mature_leaf,
            m.leaf_area_first_leaf,
            m.leaf_area_mature_leaf
        )
end

function PlantSimEngine.run!(::FinalPotentialAreaModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    status.final_potential_area = prev_value(status, :final_potential_area, default=status.final_potential_area)
end
