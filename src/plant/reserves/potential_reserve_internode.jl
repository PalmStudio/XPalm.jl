"""
    PotentialReserveInternode(nsc_max)

Compute the remaining internode reserve capacity in XPalm's assimilate
currency (g CH2O-equivalent).

# Arguments

- `nsc_max`: maximum non-structural carbohydrate reserve relative to
  internode structural dry mass (g CH2O-equivalent gDM⁻¹)

# Inputs

- `biomass`: internode structural dry mass (gDM)
- `reserve`: current reserve (g CH2O-equivalent)

# Outputs

- `potential_reserve`: remaining reserve capacity (g CH2O-equivalent)
"""
struct PotentialReserveInternode{T} <: AbstractReserve_FillingModel
    nsc_max::T
end

# Compatibility with the short-lived elemental-carbon API. XPalm's canonical
# assimilate currency is CH2O-equivalent, so `carbon_concentration` is ignored.
PotentialReserveInternode(nsc_max, carbon_concentration) =
    PotentialReserveInternode(nsc_max)

function PotentialReserveInternode(; nsc_max=0.3, carbon_concentration=nothing)
    return PotentialReserveInternode(nsc_max)
end

PlantSimEngine.inputs_(::PotentialReserveInternode) = (
    biomass=PlantSimEngine.Required(Real),
    reserve=PlantSimEngine.Default(0.0),
)
PlantSimEngine.outputs_(::PotentialReserveInternode) = (potential_reserve=0.0,)
PlantSimEngine.variable_contracts_(::PotentialReserveInternode) = (
    biomass=_STRUCTURAL_DRY_MASS,
    reserve=_CH2O_EQUIVALENT_STOCK,
    potential_reserve=_CH2O_EQUIVALENT_STOCK,
)

function PlantSimEngine.run!(m::PotentialReserveInternode, st, environment, constants, context)
    st.potential_reserve = st.biomass * m.nsc_max - st.reserve
end
