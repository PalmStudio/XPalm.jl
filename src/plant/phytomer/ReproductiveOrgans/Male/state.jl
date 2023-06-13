struct MaleStateModel{T} <: AbstractStateModel
    TT_flowering::T
    duration_abortion::T
    duration_flowering_male::T
end

PlantSimEngine.inputs_(::MaleStateModel) = (TT_since_init=-Inf,)
PlantSimEngine.outputs_(::MaleStateModel) = NamedTuple()

function PlantSimEngine.run!(m::MaleStateModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)

    status.sex = prev_value(status, :sex, default="undetermined")
    status.abortion = prev_value(status, :abortion, default=false)
    status.sex != "male" || mtg.type.state == Aborted() && return # if the sex is not male or the inflo is aborted, no need to compute 

    if (status.abortion == true)
        mtg.type.state = Aborted()
    end

    if (status.abortion == false)
        if status.TT_since_init > m.TT_flowering + m.duration_flowering_male
            mtg.type.state = Scenescent()
            # no more growth and carbon demand
        else
            # compute demand and growth
            PlantSimEngine.run!(models.final_potential_biomass, models, status, meteo, constants, mtg)
            PlantSimEngine.run!(models.carbon_demand, models, status, meteo, constants, mtg)
            PlantSimEngine.run!(models.biomass, models, status, meteo, constants, mtg)

            # and give the state
            if status.TT_since_init > m.TT_flowering
                mtg.type.state = Flowering() #NB: if before TT_flowering it is Initiated
            end
        end
    end
end
