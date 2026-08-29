"""
    PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution, carbon_concentration)

Compute the remaining leaf reserve capacity in the plant carbon currency.

`lma_max - lma_min` represents the additional dry mass that can be stored per
unit leaflet area. `carbon_concentration` converts that capacity to gC.

# Inputs

- `leaf_area`: leaflet area (m²)
- `reserve`: current leaf reserve (gC)

# Outputs

- `potential_reserve`: remaining reserve capacity (gC)
"""
struct PotentialReserveLeaf{T} <: AbstractReserve_FillingModel
    lma_min::T
    lma_max::T
    leaflets_biomass_contribution::T
    carbon_concentration::T
end

PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution) =
    PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution, 0.48)

PotentialReserveLeaf(;
    lma_min=80.0,
    lma_max=200.0,
    leaflets_biomass_contribution=0.30,
    carbon_concentration=0.48,
) = PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution, carbon_concentration)

PlantSimEngine.inputs_(::PotentialReserveLeaf) = (
    leaf_area=PlantSimEngine.Required(Real),
    reserve=PlantSimEngine.Default(0.0),
)
PlantSimEngine.outputs_(::PotentialReserveLeaf) = (potential_reserve=0.0,)

function PlantSimEngine.run!(m::PotentialReserveLeaf, st, environment, constants, context)
    if st.state == :opened
        st.potential_reserve = (m.lma_max - m.lma_min) * m.carbon_concentration *
                               st.leaf_area / m.leaflets_biomass_contribution - st.reserve
    else
        st.potential_reserve = 0.0
    end

    return nothing
end
