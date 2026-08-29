
"""
MaleBiomass(respiration_cost)
MaleBiomass(respiration_cost=1.44)

Compute male biomass  from daily carbon allocation

# Arguments

- `respiration_cost`: construction cost (gC-equivalent allocated gDM⁻¹ produced)

# inputs
- `carbon_allocation`: carbon allocated to the male inflorescence (gC-equivalent)
- `state`: state of the inflorescence 

# outputs
- `biomass`: male-inflorescence dry mass (gDM)
- `litter_male`: senescent male-inflorescence dry mass transferred to litter (gDM)
"""
struct MaleBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
end

MaleBiomass(; respiration_cost=1.44) = MaleBiomass(respiration_cost)

PlantSimEngine.inputs_(::MaleBiomass) = (
    carbon_allocation=PlantSimEngine.Default(0.0),
    state=PlantSimEngine.Required(Symbol),
)
PlantSimEngine.outputs_(::MaleBiomass) = (biomass=0.0, litter_male=0.0,)

# Applied at the male inflorescence scale:
function PlantSimEngine.run!(m::MaleBiomass, st, environment, constants, context=nothing)

    if st.state == :aborted
        st.biomass = 0.0
        return # if it is aborted, no biomass, because it is done before flowering
    end

    if st.state == :harvested || st.state == :senescent
        st.litter_male = copy(st.biomass)
        st.biomass = 0.0
        return # if it is aborted, no biomass
    end

    st.biomass += st.carbon_allocation / m.respiration_cost
end
