"""
FemaleCarbonDemandModel(lma_min, respiration_cost, leaflets_biomass_contribution)
FemaleCarbonDemandModel(lma_min= 80.0, respiration_cost=1.44, leaflets_biomass_contribution=0.35)
    
Carbon demand of the female inflorescence based on the final_potential_fruit_biomass and final_potential_stalk_biomass

# Arguments

- `respiration_cost`: growth respiration cost (g g⁻¹)
-`respiration_cost_oleosynthesis`:
-`TT_flowering`:
-`TT_harvest`:
- `duration_fruit_setting`: period of thermal time after flowering that determines the number of flowers in the bunch that become fruits, *i.e.* fruit set (degree days).
-`oil_content`:
-`fraction_period_oleosynthesis`:- `fraction_period_oleosynthesis`: fraction of the duration between flowering and harvesting when oleosynthesis occurs
-`fraction_period_stalk`:

- `lma_min`: minimum leaf mass area (g m⁻²)

- `leaflets_biomass_contribution`: contribution of the leaflet biomass to the total leaf biomass (including rachis)

# Inputs
- `potential_area`: potential leaf area (m2) 
- `state`: state of the leaf

# Outputs
- `carbon_demand`: daily leaf carbon demand

"""
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
    duration_dev_stalk = fraction_period_stalk * (TT_harvest - TT_flowering)

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
PlantSimEngine.outputs_(::FemaleCarbonDemandModel) = (carbon_demand=0.0, carbon_demand_oil=-Inf, carbon_demand_non_oil=-Inf, carbon_demand_stalk=-Inf,)

function PlantSimEngine.run!(m::FemaleCarbonDemandModel, models, status, meteo, constants, extra=nothing)

    # We initialize the carbon demand at 0.0 because we add to it with some conditions below

    # If it is harvested or there are no fruits, there is no carbon demand
    status.carbon_demand_stalk = 0.0
    status.carbon_demand_non_oil = 0.0
    status.carbon_demand_oil = 0.0
    status.carbon_demand = 0.0

    if status.state == "Harvested" || status.state == "Aborted"
        return
    end

    # If there are no fruits, there is no carbon demand
    if status.fruits_number > 0
        # As soon as we have fruits:
        if status.TT_since_init >= m.TT_harvest - m.duration_dev_bunch
            status.carbon_demand_non_oil = status.fruits_number * status.final_potential_fruit_biomass * (1.0 - m.oil_content) * m.respiration_cost * (status.TEff / m.duration_dev_bunch)
            status.carbon_demand += status.carbon_demand_non_oil
        end

        if status.state == "Oleosynthesis"
            final_potential_oil_mass = status.fruits_number * status.final_potential_fruit_biomass * m.oil_content
            status.carbon_demand_oil = final_potential_oil_mass * m.respiration_cost_oleosynthesis * (status.TEff / m.duration_dev_oleo)
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