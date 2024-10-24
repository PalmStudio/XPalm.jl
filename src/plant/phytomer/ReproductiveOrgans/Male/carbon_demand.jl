struct MaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    TT_flowering::T
    duration_flowering_male::T
end

PlantSimEngine.inputs_(::MaleCarbonDemandModel) = (final_potential_biomass=-Inf, TEff=-Inf, state="undetermined",)
PlantSimEngine.outputs_(::MaleCarbonDemandModel) = (carbon_demand=0.0,)

function PlantSimEngine.run!(m::MaleCarbonDemandModel, models, st, meteo, constants, extra=nothing)
    if st.state == "Aborted" || st.state == "Senescent" # if abortion no more carbon demand
        st.carbon_demand = 0.0
    else
        st.carbon_demand = (st.final_potential_biomass * (st.TEff / (m.TT_flowering + m.duration_flowering_male))) / m.respiration_cost
    end
end