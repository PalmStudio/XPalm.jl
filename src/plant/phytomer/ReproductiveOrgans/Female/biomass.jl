
"""
FemaleBiomass(respiration_cost,respiration_cost_oleosynthesis)
FemaleBiomass(respiration_cost=1.44,respiration_cost_oleosynthesis=3.2)

Compute female biomass (inflo and bunch) from daily carbon allocation

# Arguments

- `respiration_cost`: respiration cost  (g g-1)
- `respiration_cost_oleosynthesis`: respiration cost of fruits oil  (g g-1)

# inputs
- `carbon_allocation`: carbon allocated to female inflo
- `carbon_demand_stalk`: carbon demand of the stalk
- `carbon_demand_non_oil`: carbon demand of non oil components of fruits
- `carbon_demand_oil`: carbon demand of fruits oil

# outputs
- `biomass`: total ifnlo/bunch biomass
- `biomass_stalk`: stalk biomass
- `biomass_fruits`: fruits biomass


# Example

```jldoctest

```

"""
struct FemaleBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
    respiration_cost_oleosynthesis::T
end

PlantSimEngine.inputs_(::FemaleBiomass) = (carbon_allocation=0.0, state="undetermined", carbon_demand_non_oil=0.0, carbon_demand_oil=0.0, carbon_demand_stalk=0.0)
PlantSimEngine.outputs_(::FemaleBiomass) = (biomass=0.0, biomass_stalk=0.0, biomass_fruits=0.0,)

# Applied at the Female inflorescence scale:
function PlantSimEngine.run!(m::FemaleBiomass, models, st, meteo, constants, extra=nothing)
    st.state == "Aborted" || st.state == "Harvested" && return # if it is aborted, no need to compute 

    st.carbon_allocation == 0.0 && return # no carbon allocation -> no biomass increase


    demand_tot = st.carbon_demand_non_oil + st.carbon_demand_oil + st.carbon_demand_stalk
    demand_tot == 0.0 && return # no carbon demand -> no biomass increase


    allocation_nonoil = st.carbon_demand_non_oil <= 0.0 ? 0.0 : st.carbon_allocation * st.carbon_demand_non_oil / demand_tot
    allocation_oil = st.carbon_demand_oil <= 0.0 ? 0.0 : st.carbon_allocation * st.carbon_demand_oil / demand_tot
    allocation_stalk = st.carbon_demand_stalk <= 0.0 ? 0.0 : st.carbon_allocation * st.carbon_demand_stalk / demand_tot

    st.biomass_stalk += allocation_stalk / m.respiration_cost
    st.biomass_fruits += allocation_nonoil / m.respiration_cost + allocation_oil / m.respiration_cost_oleosynthesis

    st.biomass = st.biomass_stalk + st.biomass_fruits
end