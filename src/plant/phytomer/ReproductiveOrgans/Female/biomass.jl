
struct FemaleBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
    respiration_cost_oleosynthesis::T
end

PlantSimEngine.inputs_(::FemaleBiomass) = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(::FemaleBiomass) = (biomass=-Inf,)

# Applied at the Female inflorescence scale:
function PlantSimEngine.run!(m::FemaleBiomass, models, st, meteo, constants, extra=nothing)
    state = prev_value(st, :state, default="undetermined")
    state == "Aborted" && return # if it is aborted, no need to compute 

    prev_biomass = prev_value(st, :biomass, default=st.biomass)
    if prev_biomass == -Inf
        prev_biomass = 0.0
    end

    st.biomass = prev_biomass + st.carbon_demand_non_oil / m.respiration_cost + st.carbon_demand_oil / m.respiration_cost_oleosynthesis
end