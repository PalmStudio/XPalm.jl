struct StemBiomass <: AbstractBiomassModel end

PlantSimEngine.inputs_(::StemBiomass) = (biomass_internodes=[0.0],)
PlantSimEngine.outputs_(::StemBiomass) = (biomass=0.0,)

# Applied at the stem scale:
function PlantSimEngine.run!(::StemBiomass, models, st, meteo, constants, extra=nothing)
    st.biomass = sum(st.biomass_internodes)
end