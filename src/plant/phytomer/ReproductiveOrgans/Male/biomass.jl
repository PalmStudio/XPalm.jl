
struct MaleBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
end

PlantSimEngine.inputs_(::MaleBiomass) = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(::MaleBiomass) = (biomass=-Inf,)

# Applied at the male inflorescence scale:
function PlantSimEngine.run!(m::MaleBiomass, models, st, meteo, constants, extra=nothing)

    st.sex = prev_value(st, :sex, default="undetermined")
    st.abortion = prev_value(st, :abortion, default=false)
    st.sex != "male" || st.abortion == true && return # if the sex is not male or the inflorescence is aborted, no need to compute 

    prev_biomass = prev_value(st, :biomass, default=st.biomass)
    if prev_biomass == -Inf
        prev_biomass = 0.0
    end

    st.biomass = prev_biomass + st.carbon_allocation / m.respiration_cost
end