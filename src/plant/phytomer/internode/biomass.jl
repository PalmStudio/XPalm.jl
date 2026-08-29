


"""
InternodeBiomass(respiration_cost)
InternodeBiomass(respiration_cost=1.44)

Compute internode biomass from daily carbon allocation

# Arguments

- `initial_biomass`: initial structural dry mass of the internode (gDM)
- `respiration_cost`: construction cost (gC-equivalent allocated gDM⁻¹ produced)

# Inputs

- `carbon_allocation`: carbon allocated to the internode (gC-equivalent)

# Outputs

- `biomass`: internode structural dry mass (gDM)
"""
struct InternodeBiomass{T} <: AbstractBiomassModel
    initial_biomass::T
    respiration_cost::T
end

InternodeBiomass(; initial_biomass=0.0, respiration_cost=1.44) = InternodeBiomass(initial_biomass, respiration_cost)

PlantSimEngine.inputs_(::InternodeBiomass) = (
    carbon_allocation=PlantSimEngine.Default(0.0),
)
PlantSimEngine.outputs_(m::InternodeBiomass) = (biomass=m.initial_biomass,)

# Applied at the Internode scale:
function PlantSimEngine.run!(m::InternodeBiomass, st, environment, constants, context=nothing)
    st.biomass += st.carbon_allocation / m.respiration_cost
end
