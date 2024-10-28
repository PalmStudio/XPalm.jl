"""
LeafBiomass(respiration_cost)
LeafBiomass(respiration_cost=1.44)

Compute leaf biomass from carbon_allocation

# Arguments
- `respiration_cost`: respiration cost of the leaf (g.g-1)
- `initial_biomass`: initial biomass of the leaf (g)

# inputs
- `carbon_allocation`: carbon allocated to the leaf (g)

# outputs
- `biomass`: leaf biomass (g)
"""
# Used after init:
struct LeafBiomass{T} <: AbstractBiomassModel
    initial_biomass::T
    respiration_cost::T
end

LeafBiomass(; initial_biomass=0.0, respiration_cost=1.44) = LeafBiomass(initial_biomass, respiration_cost)

PlantSimEngine.inputs_(::LeafBiomass) = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(m::LeafBiomass) = (biomass=m.initial_biomass,)

# Applied at the leaf scale:
function PlantSimEngine.run!(m::LeafBiomass, models, st, meteo, constants, extra=nothing)
    st.biomass += st.carbon_allocation / m.respiration_cost
end