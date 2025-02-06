"""
    FemaleFinalPotentialFruits(
        days_increase_number_fruits,
        days_maximum_number_fruits,
        fraction_first_female,
        potential_fruit_number_at_maturity,
        potential_fruit_weight_at_maturity,
        stalk_max_biomass,
    )

# Arguments

- `days_increase_number_fruits`: age at which the number of fruits starts to increase (days)
- `days_maximum_number_fruits`: age at which the palm makes bunch of mature size with the highest number of fruits (days).
- `fraction_first_female`: size of the first bunches on a young palm relative to the size 
at maturity (dimensionless)
- `potential_fruit_number_at_maturity`: potential number of fruits at maturity (number of fruits)
- `potential_fruit_weight_at_maturity`: potential weight of one fruit at maturity (g)
- `stalk_max_biomass`: maximum biomass of the stalk (g)

# Inputs

- `initiation_age`: age at which the palm starts to make bunches (days)

# Outputs

- `potential_fruits_number`: potential number of fruits (number of fruits)
- `final_potential_fruit_biomass`: potential biomass of fruits (g)
- `final_potential_biomass_stalk`: potential biomass of stalk (g)

# Examples

```jl
using PlantSimEngine
using MultiScaleTreeGraph
using XPalmModel
using XPalmModel.Models 

node = Node(NodeMTG("/", "Plant", 1, 1))
pot_model = FemaleFinalPotentialFruits(8.0 * 365, 0.3, 2000.0, 6.5, 2100.0)

m = ModelList(
    pot_model,
    status = (initiation_age = 5000.0, )
)

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
run!(m, meteo, PlantMeteo.Constants(), node)

m[:potential_fruits_number]
```
"""
struct FemaleFinalPotentialFruits{T,I} <: AbstractFinal_Potential_BiomassModel
    days_increase_number_fruits::I
    days_maximum_number_fruits::I
    fraction_first_female::T
    potential_fruit_number_at_maturity::I
    potential_fruit_weight_at_maturity::T
    stalk_max_biomass::T
end

function FemaleFinalPotentialFruits(;
    days_increase_number_fruits=2379,
    days_maximum_number_fruits=6500,
    fraction_first_female=0.3,
    potential_fruit_number_at_maturity=2000,
    potential_fruit_weight_at_maturity=6.5,
    stalk_max_biomass=2100.0
)

    # Check the type of the inputs, promote them if necessary:
    days_increase_number_fruits, days_maximum_number_fruits, potential_fruit_number_at_maturity = promote(days_increase_number_fruits, days_maximum_number_fruits, potential_fruit_number_at_maturity)
    fraction_first_female, potential_fruit_weight_at_maturity, stalk_max_biomass = promote(fraction_first_female, potential_fruit_weight_at_maturity, stalk_max_biomass)

    FemaleFinalPotentialFruits(
        days_increase_number_fruits,
        days_maximum_number_fruits,
        fraction_first_female,
        potential_fruit_number_at_maturity,
        potential_fruit_weight_at_maturity,
        stalk_max_biomass,
    )
end

PlantSimEngine.inputs_(::FemaleFinalPotentialFruits) = (initiation_age=0,)
PlantSimEngine.outputs_(::FemaleFinalPotentialFruits) = (potential_fruits_number=-9999, final_potential_fruit_biomass=-Inf, final_potential_biomass_stalk=-Inf,)

function PlantSimEngine.run!(m::FemaleFinalPotentialFruits, models, st, meteo, constants, extra=nothing)
    coeff_dev = age_relative_value(st.initiation_age, m.days_increase_number_fruits, m.days_maximum_number_fruits, m.fraction_first_female, 1.0)

    st.potential_fruits_number = floor(Int, coeff_dev * m.potential_fruit_number_at_maturity)
    st.final_potential_fruit_biomass = coeff_dev * m.potential_fruit_weight_at_maturity
    st.final_potential_biomass_stalk = coeff_dev * m.stalk_max_biomass
end