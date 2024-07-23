
struct MaleBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
end

PlantSimEngine.inputs_(::MaleBiomass) = (carbon_allocation=-Inf, state="undetermined")
PlantSimEngine.outputs_(::MaleBiomass) = (biomass=0.0, litter_male=-Inf,)

# Applied at the male inflorescence scale:
function PlantSimEngine.run!(m::MaleBiomass, models, st, meteo, constants, extra=nothing)

    if st.state == "Aborted"
        st.biomass = 0.0
        return # if it is aborted, no biomass, because it is done before flowering
    end

    if st.state == "Senescent"
        st.litter_male = copy(st.biomass)
        st.biomass = 0.0
        return # if it is aborted, no biomass
    end

    st.biomass += st.carbon_allocation / m.respiration_cost
end