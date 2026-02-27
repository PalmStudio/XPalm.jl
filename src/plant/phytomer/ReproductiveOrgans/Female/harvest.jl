
struct BunchHarvest <: AbstractHarvestModel end

PlantSimEngine.inputs_(::BunchHarvest) = (state=:undetermined, biomass=-Inf, biomass_stalk=-Inf, biomass_fruits=-Inf, biomass_oil=-Inf, fruits_number=-9999, final_potential_oil_biomass=-Inf)
PlantSimEngine.outputs_(::BunchHarvest) = (
    biomass_bunch_harvested=0.0, biomass_stalk_harvested=0.0, biomass_fruit_harvested=0.0, biomass_oil_harvested=0.0,
    is_harvested=false, biomass_bunch_harvested_cum=0.0, biomass_oil_harvested_cum=0.0, litter=0.0, biomass_oil_harvested_potential=0.0,
    biomass_oil_harvested_potential_cum=0.0, fruits_number_harvested=0,
)

# Applied at the Female inflorescence scale:
function PlantSimEngine.run!(m::BunchHarvest, models, st, meteo, constants, extra=nothing)
    if st.state == :harvested && st.is_harvested == false
        st.biomass_bunch_harvested = st.biomass
        st.biomass_stalk_harvested = st.biomass_stalk
        st.biomass_fruit_harvested = copy(st.biomass_fruits)
        st.biomass_oil_harvested = st.biomass_oil
        st.biomass_bunch_harvested_cum = st.biomass
        st.biomass_oil_harvested_cum = st.biomass_oil
        st.biomass_oil_harvested_potential = st.final_potential_oil_biomass
        st.biomass_oil_harvested_potential_cum = st.final_potential_oil_biomass
        st.fruits_number_harvested = st.fruits_number
        st.biomass = 0.0
        st.biomass_stalk = 0.0
        st.biomass_fruits = 0.0
        st.biomass_oil = 0.0
        st.biomass_non_oil = 0.0
        st.is_harvested = true
        st.fruits_number = 0
    elseif st.state == :aborted && st.is_harvested == false
        st.litter = st.biomass
        st.biomass_bunch_harvested_cum = 0.0
        st.biomass_oil_harvested_cum = 0.0
        st.biomass_oil_harvested_potential_cum = 0.0
        st.biomass = 0.0
        st.biomass_stalk = 0.0
        st.biomass_fruits = 0.0
        st.biomass_oil = 0.0
        st.biomass_non_oil = 0.0
        st.is_harvested = true
        st.fruits_number = 0
    else# The biomass harvested should only appear on the day of harvest, otherwise it is 0 (before and after harvest)
        st.biomass_bunch_harvested = 0.0
        st.biomass_stalk_harvested = 0.0
        st.biomass_fruit_harvested = 0.0
        st.biomass_oil_harvested = 0.0
        st.biomass_oil_harvested_potential = 0.0
        # Note: biomass_bunch_harvested_cum is not reset to 0, so that it increases at every harvest
    end
end

struct PlantBunchHarvest <: AbstractHarvestModel end

PlantSimEngine.inputs_(::PlantBunchHarvest) = (biomass_bunch_harvested_organs=[-Inf], biomass_stalk_harvested_organs=[-Inf], biomass_fruit_harvested_organs=[-Inf], biomass_bunch_harvested_cum_organs=[-Inf], biomass_oil_harvested_organs=[-Inf], biomass_oil_harvested_cum_organs=[-Inf], biomass_oil_harvested_potential_organs=[-Inf], biomass_oil_harvested_potential_cum_organs=[-Inf],)
PlantSimEngine.outputs_(::PlantBunchHarvest) = (biomass_bunch_harvested=0.0, biomass_stalk_harvested=0.0, biomass_fruit_harvested=0.0, n_bunches_harvested=-9999, biomass_bunch_harvested_cum=0.0, n_bunches_harvested_cum=0, biomass_oil_harvested=0.0, biomass_oil_harvested_potential=0.0, biomass_oil_harvested_potential_cum=0.0, biomass_oil_harvested_cum=0.0, yield_gap_oil=0.0,)

# For plant scale:
function PlantSimEngine.run!(m::PlantBunchHarvest, models, st, meteo, constants, extra=nothing)
    st.biomass_bunch_harvested = sum(st.biomass_bunch_harvested_organs)
    st.biomass_stalk_harvested = sum(st.biomass_stalk_harvested_organs)
    st.biomass_fruit_harvested = sum(st.biomass_fruit_harvested_organs)
    st.biomass_oil_harvested = sum(st.biomass_oil_harvested_organs)
    st.biomass_oil_harvested_potential = sum(st.biomass_oil_harvested_potential_organs)
    st.biomass_bunch_harvested_cum = sum(st.biomass_bunch_harvested_cum_organs)
    st.biomass_oil_harvested_cum = sum(st.biomass_oil_harvested_cum_organs)
    st.biomass_oil_harvested_potential_cum = sum(st.biomass_oil_harvested_potential_cum_organs)

    st.yield_gap_oil = st.biomass_oil_harvested_potential_cum == 0.0 ? NaN : (st.biomass_oil_harvested_potential_cum - st.biomass_oil_harvested_cum) / st.biomass_oil_harvested_potential_cum

    st.n_bunches_harvested = length(filter(x -> x > zero(x), st.biomass_bunch_harvested_organs))
    st.n_bunches_harvested_cum += st.n_bunches_harvested
end
