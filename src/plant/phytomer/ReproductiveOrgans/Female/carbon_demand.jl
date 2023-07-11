struct FemaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    respiration_cost_oleosynthesis::T
    TT_flowering::T
    TT_harvest::T
    duration_fruit_setting::T
    oil_content::T
    fraction_period_oleosynthesis::T
    fraction_period_stalk::T
    # the following are computed:
    duration_dev_bunch::T
    duration_dev_oleo::T
    TT_ini_oleo::T
    duration_dev_stalk::T
end

function FemaleCarbonDemandModel(
    respiration_cost,
    respiration_cost_oleosynthesis,
    TT_flowering,
    TT_harvest,
    duration_fruit_setting,
    oil_content,
    fraction_period_oleosynthesis,
    fraction_period_stalk
)

    @assert (TT_flowering + duration_fruit_setting) < TT_harvest "TT_flowering + duration_fruit_setting must be < TT_harvest"
    @assert 0.0 <= fraction_period_oleosynthesis <= 1.0 "fraction_period_oleosynthesis must be between 0 and 1"
    @assert 0.0 <= fraction_period_stalk <= 1.0 "fraction_period_stalk must be between 0 and 1"

    duration_dev_bunch = TT_harvest - (TT_flowering + duration_fruit_setting)
    duration_dev_oleo = fraction_period_oleosynthesis * duration_dev_bunch
    TT_ini_oleo = TT_flowering + duration_fruit_setting + (1.0 - fraction_period_oleosynthesis) * duration_dev_bunch
    duration_dev_stalk = fraction_period_stalk * TT_harvest

    FemaleCarbonDemandModel(
        respiration_cost,
        respiration_cost_oleosynthesis,
        TT_flowering,
        TT_harvest,
        duration_fruit_setting,
        oil_content,
        fraction_period_oleosynthesis,
        fraction_period_stalk,
        duration_dev_bunch,
        duration_dev_oleo,
        TT_ini_oleo,
        duration_dev_stalk,
    )
end

PlantSimEngine.inputs_(::FemaleCarbonDemandModel) = (final_potential_fruit_biomass=-Inf, TEff=-Inf, state="undetermined",)
PlantSimEngine.outputs_(::FemaleCarbonDemandModel) = (carbon_demand=-Inf, carbon_demand_oil=-Inf, carbon_demand_non_oil=-Inf, carbon_demand_stalk=-Inf,)

function PlantSimEngine.run!(m::FemaleCarbonDemandModel, models, status, meteo, constants, extra=nothing)
    # If it is harvested or there are no fruits, there is no carbon demand
    if status.state == "Harvested" || status.state == "Aborted"
        status.carbon_demand_stalk = 0.0
        status.carbon_demand_non_oil = 0.0
        status.carbon_demand_oil = 0.0
        status.carbon_demand = 0.0
        return
    end

    # We initialize the carbon demand at 0.0 because we add to it with some conditions below
    status.carbon_demand = 0.0

    # If there are no fruits, there is no carbon demand
    if status.fruits_number == -9999
        status.carbon_demand_non_oil = 0.0
        status.carbon_demand_oil = 0.0
    else
        # As soon as we have fruits:
        if status.TT_since_init >= m.TT_harvest - m.duration_dev_bunch
            status.carbon_demand_non_oil = status.fruits_number * status.final_potential_fruit_biomass * (1.0 - m.oil_content) * m.respiration_cost * (status.TEff / m.duration_dev_bunch)
        else
            status.carbon_demand_non_oil = 0.0
        end

        status.carbon_demand += status.carbon_demand_non_oil

        if status.state == "Oleosynthesis"
            final_potential_oil_mass = status.fruits_number * status.final_potential_fruit_biomass * m.oil_content
            status.carbon_demand_oil = final_potential_oil_mass * m.respiration_cost_oleosynthesis * (status.TEff / m.duration_dev_oleo)
            status.carbon_demand += status.carbon_demand_oil
        end
    end

    # Carbon demand for the stalk:
    if status.TT_since_init >= m.duration_dev_stalk
        status.carbon_demand_stalk = 0.0
    else
        status.carbon_demand_stalk = (status.final_potential_biomass_stalk * (status.TEff / m.duration_dev_stalk)) / m.respiration_cost
        status.carbon_demand += status.carbon_demand_stalk
    end
end