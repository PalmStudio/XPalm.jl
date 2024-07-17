struct StemBiomass <: AbstractBiomassModel end

PlantSimEngine.inputs_(::StemBiomass) = NamedTuple()
PlantSimEngine.outputs_(::StemBiomass) = (biomass=-Inf, biomass_internodes=[0.0])

# Applied at the stem scale:
function PlantSimEngine.run!(::StemBiomass, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    @assert symbol(st.node) == "Stem" "The node should be a Stem but is a $(symbol(st.node))"

    st.biomass = sum(st.biomass_internodes)
end