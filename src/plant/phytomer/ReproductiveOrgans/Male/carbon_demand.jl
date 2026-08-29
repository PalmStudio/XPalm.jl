"""
    MaleCarbonDemandModel(; respiration_cost=1.44, duration_flowering_male=1800.0)

Compute the daily carbon-equivalent construction demand of a male inflorescence.

# Arguments

- `respiration_cost`: construction cost (gC-equivalent allocated gDM⁻¹ produced)
- `duration_flowering_male`: male-inflorescence growth duration (degree days)

# Inputs

- `final_potential_biomass`: final potential dry mass (gDM)
- `TEff`: daily effective temperature (degree days d⁻¹)
- `state`: phytomer state

# Outputs

- `carbon_demand`: daily carbon-equivalent demand (gC-equivalent d⁻¹)
"""
struct MaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    duration_flowering_male::T
end

MaleCarbonDemandModel(; respiration_cost=1.44, duration_flowering_male=1800.0) =
    MaleCarbonDemandModel(promote(respiration_cost, duration_flowering_male)...)

PlantSimEngine.inputs_(::MaleCarbonDemandModel) = (
    final_potential_biomass=PlantSimEngine.Required(Real),
    TEff=PlantSimEngine.Required(Real),
    state=PlantSimEngine.Required(Symbol),
    TT_since_init=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::MaleCarbonDemandModel) = (carbon_demand=0.0,)

function PlantSimEngine.run!(m::MaleCarbonDemandModel, st, environment, constants, context=nothing)
    if st.state == :flowering
        st.carbon_demand = (st.final_potential_biomass * (st.TEff / m.duration_flowering_male)) * m.respiration_cost
    else
        st.carbon_demand = 0.0
    end
end
