struct MaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    duration_flowering_male::T
end

MaleCarbonDemandModel(; respiration_cost=1.44, duration_flowering_male=1800.0) =
    MaleCarbonDemandModel(promote(respiration_cost, duration_flowering_male)...)

PlantSimEngine.inputs_(::MaleCarbonDemandModel) = (final_potential_biomass=-Inf, TEff=-Inf, state="undetermined", TT_since_init=-Inf)
PlantSimEngine.outputs_(::MaleCarbonDemandModel) = (carbon_demand=0.0,)

function PlantSimEngine.run!(m::MaleCarbonDemandModel, models, st, meteo, constants, extra=nothing)
    if st.state == "Flowering"
        st.carbon_demand = (st.final_potential_biomass * (st.TEff / m.duration_flowering_male)) * m.respiration_cost
    else
        st.carbon_demand = 0.0
    end
end