struct MaleFinalPotentialBiomass{T} <: AbstractFinal_Potential_BiomassModel
    male_max_biomass::T
    age_mature_male::T
    fraction_biomass_first_male::T
end

PlantSimEngine.inputs_(::MaleFinalPotentialBiomass) = (initiation_age=-Inf,)
PlantSimEngine.outputs_(::MaleFinalPotentialBiomass) = (final_potential_biomass=-Inf,)

function PlantSimEngine.run!(m::MaleFinalPotentialBiomass, models, status, meteo, constants, extra=nothing)

    # st.sex = prev_value(st, :sex, default="undetermined")
    # st.abortion = prev_value(st, :abortion, default=false)
    # st.sex != "male" || st.abortion == true && return # if the sex is not male or the inflorescence is aborted, no need to compute 

    # coefficient gives a fraction of maximal biomass at mature stage depending of plant age
    coeff_dev = age_relative_value(
        status.initiation_age,
        0.0,
        m.age_mature_male,
        m.fraction_biomass_first_male,
        1.0)

    status.final_potential_biomass = coeff_dev * m.male_max_biomass
end