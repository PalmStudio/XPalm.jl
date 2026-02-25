
"""
MaleBiomass(respiration_cost)
MaleBiomass(respiration_cost=1.44)

Compute male biomass  from daily carbon allocation

# Arguments

- `respiration_cost`: respiration cost  (g g-1)

# inputs
- `carbon_allocation`: carbon allocated to female inflo
- `state`: state of the inflorescence 

# outputs
- `biomass`: inflo biomass
- `litter_male`: biomass of senescent inflorescent that goes to the litter 
"""
struct MaleBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
end

MaleBiomass(; respiration_cost=1.44) = MaleBiomass(respiration_cost)

PlantSimEngine.inputs_(::MaleBiomass) = (carbon_allocation=-Inf, state=:undetermined)
PlantSimEngine.outputs_(::MaleBiomass) = (biomass=0.0, litter_male=0.0,)

# Applied at the male inflorescence scale:
function PlantSimEngine.run!(m::MaleBiomass, models, st, meteo, constants, extra=nothing)

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