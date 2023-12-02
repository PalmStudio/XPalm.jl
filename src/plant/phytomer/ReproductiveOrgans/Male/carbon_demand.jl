struct MaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    TT_flowering::T
    duration_flowering_male::T
end

PlantSimEngine.inputs_(::MaleCarbonDemandModel) = (final_potential_biomass=-Inf, TEff=-Inf, state="undetermined",)
PlantSimEngine.outputs_(::MaleCarbonDemandModel) = (carbon_demand=0.0,)

function PlantSimEngine.run!(m::MaleCarbonDemandModel, models, status, meteo, constants, extra=nothing)
    state = prev_value(status, :state, default="undetermined")

    if state == "Aborted" || state == "Senescent" # if abortion no more carbon demand
        status.carbon_demand = 0.0
    else
        status.carbon_demand = (status.final_potential_biomass * (status.TEff / (m.TT_flowering + m.duration_flowering_male))) / m.respiration_cost
    end
end