struct StemBiomass <: AbstractBiomassModel end

PlantSimEngine.inputs_(::StemBiomass) = NamedTuple()
PlantSimEngine.outputs_(::StemBiomass) = (biomass=-Inf,)

# Applied at the stem scale:
function PlantSimEngine.run!(::StemBiomass, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    @assert mtg.MTG.symbol == "Stem" "The node should be a Stem but is a $(mtg.MTG.symbol)"

    timestep = rownumber(st)
    st.biomass = 0.0

    # Sum of all internode biomass:
    MultiScaleTreeGraph.traverse!(mtg, symbol="Internode") do internode
        st.biomass += internode[:models].status[timestep].biomass
    end
end