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

PlantSimEngine.inputs_(::InfloStateModel) = (TT_since_init=-Inf,)
PlantSimEngine.outputs_(::InfloStateModel) = (state="undetermined", state_organs=["undetermined"],)
PlantSimEngine.dep(::InfloStateModel) = (abortion=AbstractAbortionModel,)

# At phytomer scale
function PlantSimEngine.run!(m::InfloStateModel, models, status, meteo, constants, extra=nothing)
    status.state == "Aborted" && return # if the inflo is aborted, no need to compute 

    PlantSimEngine.run!(models.abortion, models, status, meteo, constants, extra)

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