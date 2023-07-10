
struct FemaleBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
    respiration_cost_oleosynthesis::T
end

PlantSimEngine.inputs_(::FemaleBiomass) = (carbon_allocation=-Inf, carbon_allocation_stalk=-Inf, carbon_demand_non_oil=-Inf, carbon_demand_oil=-Inf,)
PlantSimEngine.outputs_(::FemaleBiomass) = (biomass=-Inf, biomass_stalk=-Inf, biomass_fruits=-Inf,)

# Applied at the Female inflorescence scale:
function PlantSimEngine.run!(m::FemaleBiomass, models, st, meteo, constants, extra=nothing)
    prev_day = prev_row(st)

    state = prev_day.state
    state == "Aborted" || state == "Harvested" && return # if it is aborted, no need to compute 

    if prev_day.biomass_stalk == -Inf
        prev_biomass_stalk = 0.0
    else
        prev_biomass_stalk = prev_day.biomass_stalk
    end

    if prev_day.biomass_fruits == -Inf
        prev_biomass_fruits = 0.0
    else
        prev_biomass_fruits = prev_day.biomass_fruits
    end

    demand_tot = st.carbon_demand_non_oil + st.carbon_demand_oil + st.carbon_demand_stalk
    allocation_nonoil = st.carbon_allocation * st.carbon_demand_non_oil / demand_tot
    allocation_oil = st.carbon_allocation * st.carbon_demand_oil / demand_tot
    allocation_stalk = st.carbon_allocation * st.carbon_demand_stalk / demand_tot

    st.biomass_stalk = prev_biomass_stalk + allocation_stalk / m.respiration_cost
    st.biomass_fruits = prev_biomass_fruits + allocation_nonoil / m.respiration_cost + allocation_oil / m.respiration_cost_oleosynthesis

    st.biomass = st.biomass_stalk + st.biomass_fruits
end