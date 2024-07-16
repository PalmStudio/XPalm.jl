
struct BunchHarvest <: AbstractHarvestModel
    is_computed::Ref{Bool}  # Mutable flag using Ref to indicate if the model has been computed already
end

BunchHarvest() = BunchHarvest(Ref(false))

PlantSimEngine.inputs_(::BunchHarvest) = (state="undetermined", biomass=-Inf, biomass_stalk=-Inf, biomass_fruits=-Inf,)
PlantSimEngine.outputs_(::BunchHarvest) = (biomass_bunch_harvested=-Inf, biomass_stalk_harvested=-Inf, biomass_fruit_harvested=-Inf,)

# Applied at the Female inflorescence scale:
function PlantSimEngine.run!(m::BunchHarvest, models, st, meteo, constants, extra=nothing)
    if st.state == "Harvested" && !m.is_computed[]
        st.biomass_bunch_harvested = st.biomass
        st.biomass_stalk_harvested = st.biomass_stalk
        st.biomass_fruit_harvested = st.biomass_fruits
        st.biomass = 0.0
        st.biomass_stalk = 0.0
        st.biomass_fruits = 0.0
        m.is_computed[] = true
    else
        st.biomass_bunch_harvested = 0.0
        st.biomass_stalk_harvested = 0.0
        st.biomass_fruit_harvested = 0.0
    end
end

struct PlantBunchHarvest <: AbstractHarvestModel end


PlantSimEngine.inputs_(::PlantBunchHarvest) = (biomass_bunch_harvested_organs=[-Inf], biomass_stalk_harvested_organs=[-Inf], biomass_fruit_harvested_organs=[-Inf],)
PlantSimEngine.outputs_(::PlantBunchHarvest) = (biomass_bunch_harvested=-Inf, biomass_stalk_harvested=-Inf, biomass_fruit_harvested=-Inf, n_bunches_harvested=-9999)

# For plant scale:
function PlantSimEngine.run!(m::PlantBunchHarvest, models, st, meteo, constants, extra=nothing)
    st.biomass_bunch_harvested = sum(st.biomass_bunch_harvested_organs)
    st.biomass_stalk_harvested = sum(st.biomass_stalk_harvested_organs)
    st.biomass_fruit_harvested = sum(st.biomass_fruit_harvested_organs)

    st.bunches_harvested = length(filter(x -> x > zero(x), st.biomass_bunch_harvested_organs))
end
