


"""
InternodeBiomass(respiration_cost)
InternodeBiomass(respiration_cost=1.44)

Compute internode biomass from daily carbon allocation

# Arguments

- `initial_biomass`: initial biomass of the internode (g)
- `respiration_cost`: repisration cost  (g g-1)

# Inputs

- `carbon_allocation`:carbon allocated to the internode

# Outputs

- `biomass`: internode biomass (g)
"""
struct InternodeBiomass{T} <: AbstractBiomassModel
    initial_biomass::T
    respiration_cost::T
end

InternodeBiomass(; initial_biomass=0.0, respiration_cost=1.44) = InternodeBiomass(initial_biomass, respiration_cost)

PlantSimEngine.inputs_(::InternodeBiomass) = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(m::InternodeBiomass) = (biomass=m.initial_biomass,)

# Applied at the Internode scale:
function PlantSimEngine.run!(m::InternodeBiomass, models, st, meteo, constants, extra=nothing)
    st.biomass += st.carbon_allocation / m.respiration_cost
end