"""
    PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution)

Compute the remaining leaf reserve capacity in XPalm's assimilate currency.

`lma_max - lma_min` represents the additional dry mass that can be stored per
unit leaflet area. That non-structural carbohydrate capacity is represented as
g CH2O-equivalent; no elemental-carbon fraction is applied.

# Inputs

- `leaf_area`: leaflet area (m²)
- `reserve`: current leaf reserve (g CH2O-equivalent)

# Outputs

- `potential_reserve`: remaining reserve capacity (g CH2O-equivalent)
"""
struct PotentialReserveLeaf{T} <: AbstractReserve_FillingModel
    lma_min::T
    lma_max::T
    leaflets_biomass_contribution::T
end

PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution) =
    PotentialReserveLeaf(promote(lma_min, lma_max, leaflets_biomass_contribution)...)

# Compatibility with the short-lived elemental-carbon API. XPalm's canonical
# assimilate currency is CH2O-equivalent, so `carbon_concentration` is ignored.
PotentialReserveLeaf(
    lma_min,
    lma_max,
    leaflets_biomass_contribution,
    carbon_concentration,
) = PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution)

PotentialReserveLeaf(;
    lma_min=80.0,
    lma_max=200.0,
    leaflets_biomass_contribution=0.30,
    carbon_concentration=nothing,
) = PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution)

PlantSimEngine.inputs_(::PotentialReserveLeaf) = (
    leaf_area=PlantSimEngine.Required(Real),
    reserve=PlantSimEngine.Default(0.0),
)
PlantSimEngine.outputs_(::PotentialReserveLeaf) = (potential_reserve=0.0,)
PlantSimEngine.variable_contracts_(::PotentialReserveLeaf) = (
    reserve=_CH2O_EQUIVALENT_STOCK,
    potential_reserve=_CH2O_EQUIVALENT_STOCK,
)

function PlantSimEngine.run!(m::PotentialReserveLeaf, st, environment, constants, context)
    if st.state == :opened
        st.potential_reserve = (m.lma_max - m.lma_min) *
                               st.leaf_area / m.leaflets_biomass_contribution - st.reserve
    else
        st.potential_reserve = 0.0
    end

    return nothing
end
