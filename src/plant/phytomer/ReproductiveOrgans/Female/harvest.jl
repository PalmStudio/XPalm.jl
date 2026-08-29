
"""
    BunchHarvest()

Transfer a harvested bunch, or an aborted female inflorescence, out of the
standing biomass pools. All `biomass*` and `litter` variables are dry mass
(gDM); fruit counts are dimensionless.
"""
struct BunchHarvest <: AbstractHarvestModel end

PlantSimEngine.inputs_(::BunchHarvest) = (
    state=PlantSimEngine.Required(Symbol),
    biomass=PlantSimEngine.Required(Real),
    biomass_stalk=PlantSimEngine.Required(Real),
    biomass_fruits=PlantSimEngine.Required(Real),
    biomass_oil=PlantSimEngine.Required(Real),
    fruits_number=PlantSimEngine.Required(Integer),
    final_potential_oil_biomass=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::BunchHarvest) = (
    biomass=0.0,
    biomass_stalk=0.0,
    biomass_fruits=0.0,
    biomass_oil=0.0,
    biomass_non_oil=0.0,
    fruits_number=-9999,
    biomass_bunch_harvested=0.0, biomass_stalk_harvested=0.0, biomass_fruit_harvested=0.0, biomass_oil_harvested=0.0,
    is_harvested=false, biomass_bunch_harvested_cum=0.0, biomass_oil_harvested_cum=0.0, litter=0.0, biomass_oil_harvested_potential=0.0,
    biomass_oil_harvested_potential_cum=0.0, fruits_number_harvested=0,
)

# Applied at the Female inflorescence scale:
function PlantSimEngine.run!(m::BunchHarvest, st, environment, constants, context=nothing)
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

PlantSimEngine.inputs_(::PlantBunchHarvest) = (
    biomass_bunch_harvested_organs=PlantSimEngine.Required(AbstractVector),
    biomass_stalk_harvested_organs=PlantSimEngine.Required(AbstractVector),
    biomass_fruit_harvested_organs=PlantSimEngine.Required(AbstractVector),
    biomass_bunch_harvested_cum_organs=PlantSimEngine.Required(AbstractVector),
    biomass_oil_harvested_organs=PlantSimEngine.Required(AbstractVector),
    biomass_oil_harvested_cum_organs=PlantSimEngine.Required(AbstractVector),
    biomass_oil_harvested_potential_organs=PlantSimEngine.Required(AbstractVector),
    biomass_oil_harvested_potential_cum_organs=PlantSimEngine.Required(AbstractVector),
)
PlantSimEngine.outputs_(::PlantBunchHarvest) = (biomass_bunch_harvested=0.0, biomass_stalk_harvested=0.0, biomass_fruit_harvested=0.0, n_bunches_harvested=-9999, biomass_bunch_harvested_cum=0.0, n_bunches_harvested_cum=0, biomass_oil_harvested=0.0, biomass_oil_harvested_potential=0.0, biomass_oil_harvested_potential_cum=0.0, biomass_oil_harvested_cum=0.0, yield_gap_oil=0.0,)

_sum_or_zero(values) = isempty(values) ? 0.0 : sum(values)

# For plant scale:
function PlantSimEngine.run!(m::PlantBunchHarvest, st, environment, constants, context=nothing)
    st.biomass_bunch_harvested = _sum_or_zero(st.biomass_bunch_harvested_organs)
    st.biomass_stalk_harvested = _sum_or_zero(st.biomass_stalk_harvested_organs)
    st.biomass_fruit_harvested = _sum_or_zero(st.biomass_fruit_harvested_organs)
    st.biomass_oil_harvested = _sum_or_zero(st.biomass_oil_harvested_organs)
    st.biomass_oil_harvested_potential = _sum_or_zero(st.biomass_oil_harvested_potential_organs)
    st.biomass_bunch_harvested_cum = _sum_or_zero(st.biomass_bunch_harvested_cum_organs)
    st.biomass_oil_harvested_cum = _sum_or_zero(st.biomass_oil_harvested_cum_organs)
    st.biomass_oil_harvested_potential_cum = _sum_or_zero(st.biomass_oil_harvested_potential_cum_organs)

    st.yield_gap_oil = st.biomass_oil_harvested_potential_cum == 0.0 ? NaN : (st.biomass_oil_harvested_potential_cum - st.biomass_oil_harvested_cum) / st.biomass_oil_harvested_potential_cum

    st.n_bunches_harvested = count(x -> x > zero(x), st.biomass_bunch_harvested_organs)
    st.n_bunches_harvested_cum += st.n_bunches_harvested
end
