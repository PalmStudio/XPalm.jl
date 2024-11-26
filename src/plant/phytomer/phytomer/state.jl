"""
    InfloStateModel(stem_apparent_density,respiration_cost)
    InfloStateModel(stem_apparent_density=3000.0,respiration_cost=1.44)

Give the phenological state to the phytomer and the inflorescence depending on thermal time since phytomer appearance

# Arguments

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_abortion`: duration used for computing abortion rate before flowering (degree days).
- `duration_flowering_male`: duration between male flowering and senescence (degree days).
- `duration_fruit_setting`: period of thermal time after flowering that determines the number of flowers in the bunch that become fruits, *i.e.* fruit set (degree days).
- `TT_harvest`:Thermal time since phytomer appearance when the bunch is harvested (degree days)
- `fraction_period_oleosynthesis`: fraction of the duration between flowering and harvesting when oleosynthesis occurs
- `TT_ini_oleo`:thermal time for initializing oleosynthesis since phytomer appearence (degree days)

# Inputs
- `TT_since_init`: cumulated thermal time from the first day (degree C days)

# Outputs 
- `state`: phytomer state (undetermined,Aborted,Flowering,...)


# Example

```jldoctest

```

"""

struct InfloStateModel{T} <: AbstractStateModel
    TT_flowering::T
    duration_abortion::T
    duration_flowering_male::T
    duration_fruit_setting::T
    TT_harvest::T
    fraction_period_oleosynthesis::T
    TT_ini_oleo::T
    TT_senescence_male::T
end

function InfloStateModel(;
    TT_flowering=6300.0, duration_abortion=540.0, duration_flowering_male=1800.0, duration_fruit_setting=405.0, TT_harvest=12150.0, fraction_period_oleosynthesis=0.8,
    TT_senescence_male=TT_flowering + duration_flowering_male
)
    duration_dev_bunch = TT_harvest - (TT_flowering + duration_fruit_setting)
    TT_ini_oleo = TT_flowering + duration_fruit_setting + (1 - fraction_period_oleosynthesis) * duration_dev_bunch
    InfloStateModel(TT_flowering, duration_abortion, duration_flowering_male, duration_fruit_setting, TT_harvest, fraction_period_oleosynthesis, TT_ini_oleo, TT_senescence_male)
end

PlantSimEngine.inputs_(::InfloStateModel) = (TT_since_init=-Inf, sex="undetermined")
PlantSimEngine.outputs_(::InfloStateModel) = (state="undetermined", state_organs=["undetermined"],)
PlantSimEngine.dep(::InfloStateModel) = (abortion=AbstractAbortionModel,)

# At phytomer scale
function PlantSimEngine.run!(m::InfloStateModel, models, status, meteo, constants, extra=nothing)
    PlantSimEngine.run!(models.abortion, models, status, meteo, constants, extra)

    status.state == "Aborted" && return # if the inflo is aborted, no need to compute 

    if status.sex == "Male"
        if status.TT_since_init > m.TT_senescence_male
            status.state = "Scenescent"
        elseif status.TT_since_init > m.TT_flowering
            status.state = "Flowering" #NB: if before TT_flowering it is undetermined
        end

        # Give the state to the reproductive organ (it is always the second child of the first child of the phytomer):
        status.node[1][2][:plantsimengine_status].state = status.state
    elseif status.sex == "Female"
        if status.TT_since_init >= m.TT_harvest
            status.state = "Harvested"
            # Give the information to the leaf:
            status.node[1][1][:plantsimengine_status].state = "Harvested"
        elseif status.TT_since_init >= m.TT_ini_oleo
            status.state = "Oleosynthesis"
        elseif status.TT_since_init >= m.TT_flowering
            status.state = "Flowering"
        end
        # Else: status.state = "undetermined", but this is already the default value

        # Give the state to the reproductive organ:
        status.node[1][2][:plantsimengine_status].state = status.state
    end
end