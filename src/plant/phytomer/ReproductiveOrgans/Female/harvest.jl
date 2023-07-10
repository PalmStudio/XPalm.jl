
struct BunchHarvest{O} <: AbstractHarvestModel end

BunchHarvest() = BunchHarvest{Female}()

PlantSimEngine.inputs_(::BunchHarvest) = (state="undetermined", biomass=-Inf, biomass_stalk=-Inf, biomass_fruits=-Inf,)
PlantSimEngine.outputs_(::BunchHarvest) = (biomass_harvested=-Inf, biomass_stalk_harvested=-Inf, biomass_fruits_harvested=-Inf,)

# Applied at the Female inflorescence scale:
function PlantSimEngine.run!(m::BunchHarvest, models, st, meteo, constants, extra=nothing)
    prev_day = prev_row(st)

    if st.state == "Harvested" && prev_day.state != "Harvested"
        st.biomass_harvested = st.biomass
        st.biomass_stalk_harvested = st.biomass_stalk
        st.biomass_fruits_harvested = st.biomass_fruits
        st.biomass = 0.0
        st.biomass_stalk = 0.0
        st.biomass_fruits = 0.0
    else
        st.biomass_harvested = 0.0
        st.biomass_stalk_harvested = 0.0
        st.biomass_fruits_harvested = 0.0
    end
end

PlantSimEngine.inputs_(::BunchHarvest{Plant}) = NamedTuple()
PlantSimEngine.outputs_(::BunchHarvest{Plant}) = (biomass_harvested=-Inf, biomass_stalk_harvested=-Inf, biomass_fruits_harvested=-Inf, bunches_harvested=-9999)

# For plant scale:
function PlantSimEngine.run!(m::BunchHarvest{Plant}, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    timestep = rownumber(st)

    st.bunches_harvested = 0

    MultiScaleTreeGraph.traverse!(mtg, symbol="Female") do female
        st.biomass_harvested += female[:models].status[timestep].biomass_harvested
        st.biomass_stalk_harvested += female[:models].status[timestep].biomass_stalk_harvested
        st.biomass_fruits_harvested += female[:models].status[timestep].biomass_fruits_harvested

        if female[:models].status[timestep].biomass_harvested > 0.0
            st.bunches_harvested += 1
        end
    end
end
