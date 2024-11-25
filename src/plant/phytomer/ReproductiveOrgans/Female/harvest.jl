
struct BunchHarvest <: AbstractHarvestModel end

PlantSimEngine.inputs_(::BunchHarvest) = (state="undetermined", biomass=-Inf, biomass_stalk=-Inf, biomass_fruits=-Inf)
PlantSimEngine.outputs_(::BunchHarvest) = (biomass_bunch_harvested=0.0, biomass_stalk_harvested=0.0, biomass_fruit_harvested=0.0, is_harvested=false)

# Applied at the Female inflorescence scale:
function PlantSimEngine.run!(m::BunchHarvest, models, st, meteo, constants, extra=nothing)
    if st.state == "Harvested" && st.is_harvested == false
        st.biomass_bunch_harvested = st.biomass
        st.biomass_stalk_harvested = st.biomass_stalk
        st.biomass_fruit_harvested = st.biomass_fruits
        st.biomass = 0.0
        st.biomass_stalk = 0.0
        st.biomass_fruits = 0.0
        st.is_harvested = true
    else # The biomass harvested should only appear on the day of harvest, otherwise it is 0 (before and after harvest)
        st.biomass_bunch_harvested = 0.0
        st.biomass_stalk_harvested = 0.0
        st.biomass_fruit_harvested = 0.0
    end
end

struct PlantBunchHarvest <: AbstractHarvestModel end

PlantSimEngine.inputs_(::PlantBunchHarvest) = (biomass_bunch_harvested_organs=[-Inf], biomass_stalk_harvested_organs=[-Inf], biomass_fruit_harvested_organs=[-Inf],)
PlantSimEngine.outputs_(::PlantBunchHarvest) = (biomass_bunch_harvested=0.0, biomass_stalk_harvested=0.0, biomass_fruit_harvested=0.0, n_bunches_harvested=-9999)

# For plant scale:
function PlantSimEngine.run!(m::PlantBunchHarvest, models, st, meteo, constants, extra=nothing)
    st.biomass_bunch_harvested = sum(st.biomass_bunch_harvested_organs)
    st.biomass_stalk_harvested = sum(st.biomass_stalk_harvested_organs)
    st.biomass_fruit_harvested = sum(st.biomass_fruit_harvested_organs)

    st.n_bunches_harvested = length(filter(x -> x > zero(x), st.biomass_bunch_harvested_organs))
end
