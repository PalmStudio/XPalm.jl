"""
    FemaleCarbonDemandModel(
        respiration_cost,
        respiration_cost_oleosynthesis,
        TT_flowering,
        TT_fruiting,
        duration_bunch_development,
        duration_oleosynthesis,
        duration_dev_stalk,
    )

    FemaleCarbonDemandModel(;
        respiration_cost=1.44,
        respiration_cost_oleosynthesis=3.2,
        TT_flowering=10530.0,
        duration_bunch_development=1215.0,
        duration_fruit_setting=405.0,
        fraction_period_oleosynthesis=0.8,
        fraction_period_stalk=0.2
    )


Carbon demand of the female inflorescence based on the potential fruit biomass

# Arguments

- `respiration_cost`: growth respiration cost (g g⁻¹)
- `respiration_cost_oleosynthesis`: respiration cost during oleosynthesis (g g⁻¹)
- `TT_flowering`: thermal time for flowering since phytomer appearance (degree days).
- `TT_fruiting`: thermal time for fruit setting since phytomer appearance (degree days).
- `duration_bunch_development`: duration between fruit set and bunch maturity (ready for harvest) (degree days).
- `duration_oleosynthesis`: duration of oleosynthesis (degree days).
- `duration_dev_stalk`: duration of stalk development (degree days).
- `duration_fruit_setting`: period of thermal time after flowering that determines the number of flowers in the bunch that become fruits, *i.e.* fruit set (degree days).
- `fraction_period_oleosynthesis`: fraction of the duration between flowering and harvesting when oleosynthesis occurs
- `fraction_period_stalk`: fraction of the duration between flowering and harvesting when stalk development occurs

# Inputs

- `final_potential_biomass_non_oil_fruit`: potential fruit biomass that is not oil (g fruit-1)
- `final_potential_biomass_oil_fruit`: potential oil biomass in the fruit (g fruit-1)
- `TEff`: daily effective temperature (°C)
- `TT_since_init`: thermal time since the first day of the phytomer (degree days)
- `state`: state of the leaf

# Outputs

- `carbon_demand`: total carbon demand (g[sugar])
- `carbon_demand_oil`: carbon demand for oil production (g[sugar])
- `carbon_demand_non_oil`: carbon demand for non-oil production (g[sugar])
- `carbon_demand_stalk`: carbon demand for stalk development (g[sugar])
"""
struct FemaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    respiration_cost_oleosynthesis::T
    TT_flowering::T
    TT_fruiting::T
    duration_bunch_development::T
    duration_oleosynthesis::T
    duration_dev_stalk::T
end

function FemaleCarbonDemandModel(;
    respiration_cost=1.44,
    respiration_cost_oleosynthesis=3.2,
    TT_flowering=10530.0,
    duration_bunch_development=1215.0,
    duration_fruit_setting=405.0,
    fraction_period_oleosynthesis=0.8,
    fraction_period_stalk=0.2
)
    @assert duration_bunch_development > 0 "`duration_bunch_development` must be > 0"
    @assert duration_fruit_setting > 0 "`duration_fruit_setting` must be > 0"
    @assert TT_flowering > 0.0 "TT_flowering must be > 0.0"
    @assert 0.0 <= fraction_period_oleosynthesis <= 1.0 "fraction_period_oleosynthesis must be between 0 and 1"
    @assert 0.0 <= fraction_period_stalk <= 1.0 "fraction_period_stalk must be between 0 and 1"
    TT_fruiting = TT_flowering + duration_fruit_setting

    duration_oleosynthesis = fraction_period_oleosynthesis * duration_bunch_development
    duration_dev_stalk = fraction_period_stalk * (TT_fruiting + duration_bunch_development)

    FemaleCarbonDemandModel(
        promote(
            respiration_cost,
            respiration_cost_oleosynthesis,
            TT_flowering,
            TT_fruiting,
            duration_bunch_development,
            duration_oleosynthesis,
            duration_dev_stalk
        )...
    )
end

PlantSimEngine.inputs_(::FemaleCarbonDemandModel) = (final_potential_biomass_non_oil_fruit=-Inf, final_potential_biomass_oil_fruit=-Inf, fruits_number=-Inf, TEff=-Inf, state=:undetermined, TT_since_init=-Inf)
PlantSimEngine.outputs_(::FemaleCarbonDemandModel) = (carbon_demand=0.0, carbon_demand_oil=-Inf, carbon_demand_non_oil=-Inf, carbon_demand_stalk=-Inf)

function PlantSimEngine.run!(m::FemaleCarbonDemandModel, models, status, meteo, constants, extra=nothing)

    # We initialize the carbon demand at 0.0 because we add to it with some conditions below
    # If it is harvested or there are no fruits, there is no carbon demand
    status.carbon_demand_stalk = 0.0
    status.carbon_demand_non_oil = 0.0
    status.carbon_demand_oil = 0.0
    status.carbon_demand = 0.0

    if status.state == :harvested || status.state == :aborted
        return
    end

    # If there are no fruits, there is no carbon demand
    if status.fruits_number > 0
        # As soon as we have fruits:
        if status.TT_since_init >= m.TT_fruiting
            status.carbon_demand_non_oil = status.fruits_number * status.final_potential_biomass_non_oil_fruit * m.respiration_cost * (status.TEff / m.duration_bunch_development)
            status.carbon_demand += status.carbon_demand_non_oil
        end

        if status.state == :oleosynthesis
            status.carbon_demand_oil = status.fruits_number * status.final_potential_biomass_oil_fruit * m.respiration_cost_oleosynthesis * (status.TEff / m.duration_oleosynthesis)
            status.carbon_demand += status.carbon_demand_oil
        end
    end

    # Carbon demand for the stalk:
    if status.TT_since_init >= m.TT_flowering + m.duration_dev_stalk
        status.carbon_demand_stalk = 0.0
    else
        status.carbon_demand_stalk = (status.final_potential_biomass_stalk * (status.TEff / m.duration_dev_stalk)) * m.respiration_cost
        status.carbon_demand += status.carbon_demand_stalk
    end
end