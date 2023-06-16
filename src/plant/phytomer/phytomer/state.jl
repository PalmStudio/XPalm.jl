struct InfloStateModel{T} <: AbstractStateModel
    TT_flowering::T
    duration_abortion::T
    duration_flowering_male::T
    TT_harvest::T
    fraction_period_oleosynthesis::T
    TT_ini_oleo::T
end

function InfloStateModel(TT_flowering=6300.0, duration_abortion=540.0, duration_flowering_male=1800.0, TT_harvest=12150.0, fraction_period_oleosynthesis=0.8)
    TT_ini_oleo = TT_flowering + (1 - fraction_period_oleosynthesis) * (TT_harvest - TT_flowering)
    InfloStateModel(TT_flowering, duration_abortion, duration_flowering_male, TT_harvest, fraction_period_oleosynthesis, TT_ini_oleo)
end

PlantSimEngine.inputs_(::InfloStateModel) = (TT_since_init=-Inf,)
PlantSimEngine.outputs_(::InfloStateModel) = (state="undetermined",)

# At phytomer scale
function PlantSimEngine.run!(m::InfloStateModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)

    status.state = prev_value(status, :state, default="undetermined")
    status.state == "Aborted" && return # if the inflo is aborted, no need to compute 

    PlantSimEngine.run!(models.abortion, models, status, meteo, constants, mtg)

    if status.sex == "Male"
        if status.TT_since_init > m.TT_flowering + m.duration_flowering_male
            status.state = "Scenescent"
        elseif status.TT_since_init > m.TT_flowering
            status.state = "Flowering" #NB: if before TT_flowering it is undetermined
        end
        # Give the state to the reproductive organ:
        timestep = rownumber(status)
        status(mtg[1][2][:models])[timestep].state = status.state
    elseif status.sex == "Female"

        if status.TT_since_init >= m.TT_harvest
            status.state = "Harvested"
        elseif status.TT_since_init >= m.TT_ini_oleo
            status.state = "Oleosynthesis"
        elseif status.TT_since_init >= m.TT_flowering
            status.state = "Flowering"
        end
        # Else: status.state = "undetermined", but this is already the default value

        # Give the state to the reproductive organ:
        timestep = rownumber(status)
        mtg[1][2][:models].status[timestep].state = status.state
    end
end