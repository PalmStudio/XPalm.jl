"""
    StemBiomass()

Aggregate internode structural dry masses without creating an additional carbon demand.

# Inputs

- `biomass_internodes`: internode structural dry masses (gDM)

# Outputs

- `biomass`: total stem structural dry mass (gDM)
"""
struct StemBiomass <: AbstractBiomassModel end

PlantSimEngine.inputs_(::StemBiomass) = (
    biomass_internodes=PlantSimEngine.Required(AbstractVector),
)
PlantSimEngine.outputs_(::StemBiomass) = (biomass=0.0,)
PlantSimEngine.variable_contracts_(::StemBiomass) = (
    biomass_internodes=_STRUCTURAL_DRY_MASS,
    biomass=_STRUCTURAL_DRY_MASS,
)

# Applied at the stem scale:
function PlantSimEngine.run!(::StemBiomass, st, environment, constants, context=nothing)
    st.biomass = sum(st.biomass_internodes)
end
