"""
    FemaleFinalPotentialFruits(age_mature_female, fraction_first_female)

# Arguments

- `age_mature_female`: age at which the palm makes bunch of mature size (days).
- `fraction_first_female`: size of the first bunches on a young palm relative to the size 
at maturity (dimensionless)
- `potential_fruit_number_at_maturity`: potential number of fruits at maturity (number of fruits)
- `potential_fruit_weight_at_maturity`: potential weight of one fruit at maturity (g)
"""
struct FemaleFinalPotentialFruits{T,I} <: AbstractFinal_Potential_BiomassModel
    age_mature_female::T
    fraction_first_female::T
    potential_fruit_number_at_maturity::I
    potential_fruit_weight_at_maturity::T
end

PlantSimEngine.inputs_(::FemaleFinalPotentialFruits) = (initiation_age=-9999,)
PlantSimEngine.outputs_(::FemaleFinalPotentialFruits) = (potential_fruits_number=-9999, final_potential_fruit_biomass=-Inf,)

function PlantSimEngine.run!(m::FemaleFinalPotentialFruits, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    coeff_dev = age_relative_value(
        status.initiation_age,
        0.0,
        m.age_mature_female,
        m.fraction_first_female,
        1.0
    )

    status.potential_fruits_number = floor(Int, coeff_dev * m.potential_fruit_number_at_maturity)
    status.final_potential_fruit_biomass = coeff_dev * m.potential_fruit_weight_at_maturity
end

function PlantSimEngine.run!(m::FemaleFinalPotentialFruits, models, status, meteo, constants, extra=nothing)
    status.potential_fruits_number = prev_value(status, :potential_fruits_number, default=0)
    status.final_potential_fruit_biomass = prev_value(status, :final_potential_fruit_biomass, default=0.0)
end