struct MaleStateModel{T} <: AbstractStateModel
    TT_flowering::T
    duration_abortion::T
    duration_flowering_male::T
end

PlantSimEngine.inputs_(::MaleStateModel) = (TT_since_init=-Inf,)
PlantSimEngine.outputs_(::MaleStateModel) = (state="undetermined",)

# At phytomer scale, for males
function PlantSimEngine.run!(m::MaleStateModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)

    status.state = prev_value(status, :state, default="undetermined")
    status.state == "Aborted" && return # if the inflo is aborted, no need to compute 

    PlantSimEngine.run!(models.abortion, models, status, meteo, constants, mtg)

    if status.TT_since_init > m.TT_flowering + m.duration_flowering_male
        status.state = "Scenescent"
        # no more growth and carbon demand
    elseif status.TT_since_init > m.TT_flowering
        status.state = "Flowering" #NB: if before TT_flowering it is Initiated
    end
end

struct FemaleStateModel{T} <: AbstractStateModel
    TT_flowering::T
    TT_harvest::T
    fraction_period_oleosynthesis::T
    TT_ini_oleo::T
end

function FemaleStateModel(; TT_flowering, TT_harvest, fraction_period_oleosynthesis)
    TT_ini_oleo = TT_flowering + (1 - fraction_period_oleosynthesis) * (TT_harvest - TT_flowering)
    FemaleStateModel(; TT_flowering, TT_harvest, fraction_period_oleosynthesis, TT_ini_oleo)
end

PlantSimEngine.inputs_(::FemaleStateModel) = (TT_since_init=-Inf,)
PlantSimEngine.outputs_(::FemaleStateModel) = (state="undetermined",)

# At phytomer scale, for females
function PlantSimEngine.run!(m::FemaleStateModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)

    status.state = prev_value(status, :state, default="undetermined")
    status.state == "Aborted" && return # if the inflo is aborted, no need to compute 

    PlantSimEngine.run!(models.abortion, models, status, meteo, constants, mtg)

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
    status(mtg[1][2])[timestep].state = status.state
end