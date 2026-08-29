"""
    PotentialReserveInternode(nsc_max, carbon_concentration)

Compute the remaining internode reserve capacity in the plant carbon currency.

# Arguments

- `nsc_max`: maximum reserve carbon relative to internode structural carbon
- `carbon_concentration`: internode carbon concentration (gC gDM⁻¹)

# Inputs

- `biomass`: internode structural dry mass (gDM)
- `reserve`: current reserve carbon (gC)

# Outputs

- `potential_reserve`: remaining reserve capacity (gC)
"""
struct PotentialReserveInternode{T} <: AbstractReserve_FillingModel
    nsc_max::T
    carbon_concentration::T
end

PotentialReserveInternode(nsc_max) = PotentialReserveInternode(nsc_max, 0.5)

function PotentialReserveInternode(; nsc_max=0.3, carbon_concentration=0.5)
    values = promote(nsc_max, carbon_concentration)
    PotentialReserveInternode{typeof(first(values))}(values...)
end

PlantSimEngine.inputs_(::PotentialReserveInternode) = (
    biomass=PlantSimEngine.Required(Real),
    reserve=PlantSimEngine.Default(0.0),
)
PlantSimEngine.outputs_(::PotentialReserveInternode) = (potential_reserve=0.0,)

function PlantSimEngine.run!(m::PotentialReserveInternode, st, environment, constants, context)
    st.potential_reserve =
        st.biomass * m.carbon_concentration * m.nsc_max - st.reserve
end
