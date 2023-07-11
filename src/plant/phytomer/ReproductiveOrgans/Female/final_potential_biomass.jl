"""
    FemaleFinalPotentialFruits(age_mature_female, fraction_first_female)

# Arguments

- `age_mature_female`: age at which the palm makes bunch of mature size (days).
- `fraction_first_female`: size of the first bunches on a young palm relative to the size 
at maturity (dimensionless)
- `potential_fruit_number_at_maturity`: potential number of fruits at maturity (number of fruits)
- `potential_fruit_weight_at_maturity`: potential weight of one fruit at maturity (g)

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
using XPalm 

node = Node(NodeMTG("/", "Plant", 1, 1))
pot_model = XPalm.FemaleFinalPotentialFruits(8.0 * 365, 0.3, 2000.0, 6.5, 2100.0)

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
    age_mature_female::T
    fraction_first_female::T
    potential_fruit_number_at_maturity::I
    potential_fruit_weight_at_maturity::T
    stalk_max_biomass::T
end

PlantSimEngine.inputs_(::FemaleFinalPotentialFruits) = (initiation_age=-9999,)
PlantSimEngine.outputs_(::FemaleFinalPotentialFruits) = (potential_fruits_number=-9999, final_potential_fruit_biomass=-Inf, final_potential_biomass_stalk=-Inf,)

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
    status.final_potential_biomass_stalk = coeff_dev * m.stalk_max_biomass
end

function PlantSimEngine.run!(m::FemaleFinalPotentialFruits, models, status, meteo, constants, extra=nothing)
    status.potential_fruits_number = prev_value(status, :potential_fruits_number, default=0)
    status.final_potential_fruit_biomass = prev_value(status, :final_potential_fruit_biomass, default=0.0)
    status.final_potential_biomass_stalk = prev_value(status, :final_potential_biomass_stalk, default=0.0)
end