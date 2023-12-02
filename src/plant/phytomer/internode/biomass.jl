


"""
InternodeBiomass(respiration_cost)
InternodeBiomass(respiration_cost=1.44)

Compute internode biomass from daily carbon allocation

# Arguments

- `respiration_cost`: repisration cost  (g g-1)


# Example

```jldoctest

```

"""
struct InternodeBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
end


PlantSimEngine.inputs_(::InternodeBiomass) = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(::InternodeBiomass) = (biomass=0.0,)

# Applied at the Internode scale:
function PlantSimEngine.run!(m::InternodeBiomass, models, st, meteo, constants, extra=nothing)
    st.biomass += st.carbon_allocation / m.respiration_cost
end