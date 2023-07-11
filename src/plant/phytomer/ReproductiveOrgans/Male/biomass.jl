
struct MaleBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
end

PlantSimEngine.inputs_(::MaleBiomass) = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(::MaleBiomass) = (biomass=-Inf, litter_male=-Inf,)

# Applied at the male inflorescence scale:
function PlantSimEngine.run!(m::MaleBiomass, models, st, meteo, constants, extra=nothing)

    state = prev_value(st, :state, default="undetermined")
    if state == "Aborted"
        st.biomass = 0.0
        return # if it is aborted, no biomass, because it is done before flowering
    end

    prev_biomass = prev_value(st, :biomass, default=st.biomass)
    if prev_biomass == -Inf
        prev_biomass = 0.0
    end

    if state == "Senescent"
        st.litter_male = prev_biomass
        st.biomass = 0.0
        return # if it is aborted, no biomass
    end

    st.biomass = prev_biomass + st.carbon_allocation / m.respiration_cost
end