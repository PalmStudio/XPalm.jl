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

- `respiration_cost`: construction cost of non-oil tissues
  (g CH2O-equivalent allocated gDM⁻¹ produced)
- `respiration_cost_oleosynthesis`: oil construction cost
  (g CH2O-equivalent allocated gDM⁻¹ produced)
- `TT_flowering`: thermal time for flowering since phytomer appearance (degree days).
- `TT_fruiting`: thermal time for fruit setting since phytomer appearance (degree days).
- `duration_bunch_development`: duration between fruit set and bunch maturity (ready for harvest) (degree days).
- `duration_oleosynthesis`: duration of oleosynthesis (degree days).
- `duration_dev_stalk`: duration of stalk development (degree days).
- `duration_fruit_setting`: period of thermal time after flowering that determines the number of flowers in the bunch that become fruits, *i.e.* fruit set (degree days).
- `fraction_period_oleosynthesis`: fraction of the duration between flowering and harvesting when oleosynthesis occurs
- `fraction_period_stalk`: fraction of the duration between flowering and harvesting when stalk development occurs

# Inputs

- `final_potential_biomass_non_oil_fruit`: potential non-oil fruit dry mass (gDM fruit⁻¹)
- `final_potential_biomass_oil_fruit`: potential oil dry mass (gDM fruit⁻¹)
- `final_potential_biomass_stalk`: potential stalk dry mass (gDM)
- `TEff`: daily effective temperature (°C)
- `TT_since_init`: thermal time since the first day of the phytomer (degree days)
- `state`: state of the leaf

# Outputs

- `carbon_demand`: total assimilate demand (g CH2O-equivalent d⁻¹)
- `carbon_demand_oil`: assimilate demand for oil production
  (g CH2O-equivalent d⁻¹)
- `carbon_demand_non_oil`: assimilate demand for non-oil production
  (g CH2O-equivalent d⁻¹)
- `carbon_demand_stalk`: assimilate demand for stalk development
  (g CH2O-equivalent d⁻¹)
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

PlantSimEngine.inputs_(::FemaleCarbonDemandModel) = (
    final_potential_biomass_non_oil_fruit=PlantSimEngine.Required(Real),
    final_potential_biomass_oil_fruit=PlantSimEngine.Required(Real),
    final_potential_biomass_stalk=PlantSimEngine.Required(Real),
    fruits_number=PlantSimEngine.Required(Real),
    TEff=PlantSimEngine.Required(Real),
    state=PlantSimEngine.Required(Symbol),
    TT_since_init=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::FemaleCarbonDemandModel) = (carbon_demand=0.0, carbon_demand_oil=-Inf, carbon_demand_non_oil=-Inf, carbon_demand_stalk=-Inf)
PlantSimEngine.variable_contracts_(::FemaleCarbonDemandModel) = (
    final_potential_biomass_non_oil_fruit=_STRUCTURAL_DRY_MASS,
    final_potential_biomass_oil_fruit=_STRUCTURAL_DRY_MASS,
    final_potential_biomass_stalk=_STRUCTURAL_DRY_MASS,
    carbon_demand=_DAILY_CH2O_EQUIVALENT_FLOW,
    carbon_demand_oil=_DAILY_CH2O_EQUIVALENT_FLOW,
    carbon_demand_non_oil=_DAILY_CH2O_EQUIVALENT_FLOW,
    carbon_demand_stalk=_DAILY_CH2O_EQUIVALENT_FLOW,
)

function PlantSimEngine.run!(m::FemaleCarbonDemandModel, status, environment, constants, context=nothing)

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
            status.carbon_demand_non_oil = status.fruits_number *
                                           status.final_potential_biomass_non_oil_fruit *
                                           m.respiration_cost *
                                           (status.TEff / m.duration_bunch_development)
            status.carbon_demand += status.carbon_demand_non_oil
        end

        if status.state == :oleosynthesis
            status.carbon_demand_oil = status.fruits_number *
                                       status.final_potential_biomass_oil_fruit *
                                       m.respiration_cost_oleosynthesis *
                                       (status.TEff / m.duration_oleosynthesis)
            status.carbon_demand += status.carbon_demand_oil
        end
    end

    # Carbon demand for the stalk:
    if status.TT_since_init >= m.TT_flowering + m.duration_dev_stalk
        status.carbon_demand_stalk = 0.0
    else
        status.carbon_demand_stalk = status.final_potential_biomass_stalk *
                                     (status.TEff / m.duration_dev_stalk) *
                                     m.respiration_cost
        status.carbon_demand += status.carbon_demand_stalk
    end
end
