struct FemaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    respiration_cost_oleosynthesis::T
    TT_flowering::T
    TT_harvest::T
    duration_fruit_setting::T
    oil_content::T
    fraction_period_oleosynthesis::T
    # the following are computed:
    duration_dev_bunch::T
    duration_dev_oleo::T
    TT_ini_oleo::T
end

function FemaleCarbonDemandModel(
    respiration_cost,
    respiration_cost_oleosynthesis,
    TT_flowering,
    TT_harvest,
    duration_fruit_setting,
    oil_content,
    fraction_period_oleosynthesis
)

    @assert (TT_flowering + duration_fruit_setting) < TT_harvest "TT_flowering + duration_fruit_setting must be < TT_harvest"
    @assert 0.0 <= fraction_period_oleosynthesis <= 1.0 "fraction_period_oleosynthesis must be between 0 and 1"

    duration_dev_bunch = TT_harvest - (TT_flowering + duration_fruit_setting)
    duration_dev_oleo = fraction_period_oleosynthesis * duration_dev_bunch
    TT_ini_oleo = TT_flowering + duration_fruit_setting + (1.0 - fraction_period_oleosynthesis) * duration_dev_bunch

    FemaleCarbonDemandModel(
        respiration_cost,
        respiration_cost_oleosynthesis,
        TT_flowering,
        TT_harvest,
        duration_fruit_setting,
        oil_content,
        fraction_period_oleosynthesis,
        duration_dev_bunch,
        duration_dev_oleo,
        TT_ini_oleo
    )
end

PlantSimEngine.inputs_(::FemaleCarbonDemandModel) = (potential_fruits_number=-Inf, final_potential_fruit_biomass=-Inf, TEff=-Inf, state="undetermined", sex="undetermined")
PlantSimEngine.outputs_(::FemaleCarbonDemandModel) = (carbon_demand=-Inf, carbon_demand_oil=-Inf, carbon_demand_non_oil=-Inf)

function PlantSimEngine.run!(m::FemaleCarbonDemandModel, models, status, meteo, constants, extra=nothing)
    # If it is harvested or there are no fruits, there is no carbon demand
    if status.state == "Harvested" || status.fruits_number == -Inf
        status.carbon_demand = 0.0
        return
    end

    # As soon as we have fruits:
    if status.TT_since_init >= m.TT_harvest - m.duration_dev_bunch
        status.carbon_demand_non_oil = status.fruits_number * status.final_potential_fruit_biomass * (1.0 - m.oil_content) * m.respiration_cost * (status.TEff / m.duration_dev_bunch)
    end

    status.carbon_demand = status.carbon_demand_non_oil

    if status.state == "Oleosynthesis"
        final_potential_oil_mass = status.fruits_number * status.final_potential_fruit_biomass * m.oil_content
        status.carbon_demand_oil = final_potential_oil_mass * m.respiration_cost_oleosynthesis * (status.TEff / m.duration_dev_oleo)
        status.carbon_demand += status.carbon_demand_oil
    end
end