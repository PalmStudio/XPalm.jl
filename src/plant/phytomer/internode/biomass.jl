
struct InternodeBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
end


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


PlantSimEngine.inputs_(::InternodeBiomass) = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(::InternodeBiomass) = (biomass=-Inf,)

# Applied at the Internode scale:
function PlantSimEngine.run!(m::InternodeBiomass, models, st, meteo, constants, extra=nothing)
    prev_biomass = prev_value(st, :biomass, default=st.biomass)
    if prev_biomass == -Inf
        prev_biomass = 0.0
    end

    st.biomass = prev_biomass + st.carbon_allocation / m.respiration_cost
end