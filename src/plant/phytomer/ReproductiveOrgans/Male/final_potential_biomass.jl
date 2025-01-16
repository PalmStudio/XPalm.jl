"""
    MaleFinalPotentialBiomass(male_max_biomass, age_mature_male, fraction_biomass_first_male)

# Arguments

- `male_max_biomass`: maximal biomass of a male (gC)
- `age_mature_male`: age at which the palm plant reaches a mature state for producing male inflorescences (days)
- `fraction_biomass_first_male`: fraction of the maximal biomass that first males can reach (dimensionless)

# Inputs

- `initiation_age`: age of the plant when the organ was initiated (days)

# Outputs

- `final_potential_biomass`: final potential biomass of the male inflorescence (gC)
"""
struct MaleFinalPotentialBiomass{T} <: AbstractFinal_Potential_BiomassModel
    male_max_biomass::T
    age_mature_male::T
    fraction_biomass_first_male::T
end

PlantSimEngine.inputs_(::MaleFinalPotentialBiomass) = (initiation_age=0,)
PlantSimEngine.outputs_(::MaleFinalPotentialBiomass) = (final_potential_biomass=-Inf,)

function PlantSimEngine.run!(m::MaleFinalPotentialBiomass, models, status, meteo, constants, extra=nothing)
    # coefficient gives a fraction of maximal biomass at mature stage depending of plant age
    coeff_dev = age_relative_value(
        status.initiation_age,
        0.0,
        m.age_mature_male,
        m.fraction_biomass_first_male,
        1.0
    )

    status.final_potential_biomass = coeff_dev * m.male_max_biomass
end