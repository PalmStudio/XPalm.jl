struct MaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    TT_flowering::T
    duration_flowering_male::T
end

PlantSimEngine.inputs_(::MaleCarbonDemandModel) = (final_potential_biomass=-Inf, TEff=-Inf,
)
PlantSimEngine.outputs_(::MaleCarbonDemandModel) = (carbon_demand=-Inf,)

function PlantSimEngine.run!(m::MaleCarbonDemandModel, models, status, meteo, constants, extra=nothing)

    status.abortion = prev_value(status, :abortion, default=false)
    status.sex != "Male" && return # if the sex is not male, no need to compute 

    if status.abortion == true # if abortion no more carbon demand
        status.carbon_demand = 0.0
    else
        status.carbon_demand = (status.final_potential_biomass * (status.TEff / (m.TT_flowering + m.duration_flowering_male))) / m.respiration_cost
    end
end