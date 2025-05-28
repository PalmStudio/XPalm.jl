"""
    InfloStateModel(TT_flowering, TT_fruiting, TT_harvest, TT_ini_oleo, TT_senescence)    
    InfloStateModel(;
        TT_flowering=6300.0, duration_flowering_male=1800.0, duration_fruit_setting=405.0, duration_bunch_development=5445.0, fraction_period_oleosynthesis=0.8,
    )
    
Computes the phenological state to the phytomer and the inflorescence depending on thermal time since phytomer appearance.
The first method takes the thermal times directly as arguments, while the second one requires only the flowering time, and all other values relative to it.

# Arguments

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `TT_fruiting`: thermal time for fruit setting since phytomer appearence (degree days).
- `TT_harvest`: thermal time for harvesting since phytomer appearence (degree days).
- `TT_ini_oleo`: thermal time for initializing oleosynthesis since phytomer appearence (degree days).
- `TT_senescence_male`: thermal time for male senescence since phytomer appearence (degree days).
- `duration_flowering_male`: duration in thermal time between male flowering and senescence (degree days).
- `duration_fruit_setting`: duration between flowering and fruit set (degree days).
- `duration_bunch_development`: duration between fruit set and bunch maturity (ready for harvest) (degree days).
- `fraction_period_oleosynthesis`: fraction of the duration between flowering and harvesting when oleosynthesis occurs

# Inputs

- `TT_since_init`: cumulated thermal time from the first day (degree C days)

# Outputs

The `state` of the phytomer. For a male inflorescence, the state can be one of the following:

- "Aborted": the inflorescence is aborted (computed by the `AbortionModel`)
- "Flowering": the inflorescence is flowering
- "Senescent": the inflorescence is senescent
- "Pruned": the inflorescence is pruned (this can happen if the inflorescence is not harvested)

For a female inflorescence, the state can be one of the following:

- "Aborted": the inflorescence is aborted (computed by the `AbortionModel`)
- "Flowering": the inflorescence is flowering
- "FruitSetting": the inflorescence is setting fruits
- "Oleosynthesis": the inflorescence is synthesizing oil
- "Harvested": the inflorescence is harvested

Note that the state is also given to the reproductive organ (the second child of the first child of the phytomer), and to the
leaf if the inflorescence is harvested (in which case the leaf is set to "Pruned").
"""

struct InfloStateModel{T} <: AbstractStateModel
    TT_flowering::T
    TT_fruiting::T
    TT_harvest::T
    TT_ini_oleo::T
    TT_senescence_male::T
end

function InfloStateModel(;
    TT_flowering=6300.0, duration_flowering_male=1800.0, duration_fruit_setting=405.0, duration_bunch_development=5445.0, fraction_period_oleosynthesis=0.8,
)
    @assert TT_flowering > 0.0 "TT_flowering must be > 0.0"
    @assert duration_flowering_male > 0.0 "duration_flowering_male must be > 0.0"
    @assert duration_fruit_setting > 0.0 "duration_fruit_setting must be > 0.0"
    @assert duration_bunch_development > 0.0 "duration_bunch_development must be > 0.0"
    @assert 0.0 <= fraction_period_oleosynthesis <= 1.0 "fraction_period_oleosynthesis must be between 0 and 1"

    TT_senescence_male = TT_flowering + duration_flowering_male
    TT_ini_oleo = TT_flowering + duration_fruit_setting + (1 - fraction_period_oleosynthesis) * duration_bunch_development
    TT_fruiting = TT_flowering + duration_fruit_setting
    TT_harvest = TT_fruiting + duration_bunch_development

    InfloStateModel(promote(TT_flowering, TT_fruiting, TT_harvest, TT_ini_oleo, TT_senescence_male)...)
end

PlantSimEngine.inputs_(::InfloStateModel) = (TT_since_init=-Inf, sex="undetermined")
PlantSimEngine.outputs_(::InfloStateModel) = (state="undetermined", state_organs=["undetermined"],)
PlantSimEngine.dep(::InfloStateModel) = (abortion=AbstractAbortionModel,)

# At phytomer scale
function PlantSimEngine.run!(m::InfloStateModel, models, status, meteo, constants, extra=nothing)
    status.state == "Aborted" && return # if the inflo is aborted, no need to compute 
    status.state == "Harvested" && return # no need to compute if harvested (can also happen from the leaf side if pruned)

    PlantSimEngine.run!(models.abortion, models, status, meteo, constants, extra)

    if status.sex == "Male"
        if status.TT_since_init >= m.TT_senescence_male
            status.state = "Senescent"
        elseif status.TT_since_init >= m.TT_flowering
            status.state = "Flowering" #NB: if before TT_flowering it is undetermined
        end

        # Give the state to the reproductive organ (it is always the second child of the first child of the phytomer):
        status.node[1][2][:plantsimengine_status].state = status.state
    elseif status.sex == "Female"
        if status.TT_since_init >= m.TT_harvest
            status.state = "Harvested"
            # Give the information to the leaf (prune it):
            status.node[1][1][:plantsimengine_status].state = "Pruned"
        elseif status.TT_since_init >= m.TT_ini_oleo
            status.state = "Oleosynthesis"
        elseif status.TT_since_init >= m.TT_fruiting
            status.state = "FruitSetting"
        elseif status.TT_since_init >= m.TT_flowering
            status.state = "Flowering"
        end
        # Else: status.state = "undetermined", but this is already the default value

        # Give the state to the reproductive organ:
        status.node[1][2][:plantsimengine_status].state = status.state
    end
end