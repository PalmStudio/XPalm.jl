"""
LeafBiomass(respiration_cost)
LeafBiomass(respiration_cost=1.44)

Compute structural leaf dry mass from carbon allocation and partition it among
leaflets, rachis and petiole.

The construction cost converts CH2O-equivalent allocation into dry mass.

# Arguments
- `respiration_cost`: construction cost
  (g CH2O-equivalent allocated gDM⁻¹ produced)
- `initial_biomass`: initial structural dry mass of the leaf (gDM)
- `leaflets_biomass_contribution`: leaflet fraction of structural leaf dry mass
- `rachis_biomass_contribution`: rachis fraction of structural leaf dry mass
- `petiole_biomass_contribution`: petiole fraction of structural leaf dry mass

# inputs
- `carbon_allocation`: assimilate allocated to the leaf (g CH2O-equivalent)

# outputs
- `biomass`: structural leaf dry mass (gDM), equal to the sum of all three compartments
- `biomass_leaflets`: structural leaflet dry mass (gDM)
- `biomass_rachis`: structural rachis dry mass (gDM)
- `biomass_petiole`: structural petiole dry mass (gDM)
"""
# Used after init:
struct LeafBiomass{T} <: AbstractBiomassModel
    initial_biomass::T
    respiration_cost::T
    leaflets_biomass_contribution::T
    rachis_biomass_contribution::T
    petiole_biomass_contribution::T

    function LeafBiomass{T}(
        initial_biomass::T,
        respiration_cost::T,
        leaflets_biomass_contribution::T,
        rachis_biomass_contribution::T,
        petiole_biomass_contribution::T,
    ) where {T}
        contributions = (
            leaflets_biomass_contribution,
            rachis_biomass_contribution,
            petiole_biomass_contribution,
        )
        any(x -> x < zero(x), contributions) &&
            throw(ArgumentError("leaf biomass contributions must be non-negative"))
        isapprox(sum(contributions), one(sum(contributions)); atol=1.0e-8, rtol=1.0e-8) ||
            throw(ArgumentError("leaflets, rachis and petiole biomass contributions must sum to 1"))
        new{T}(
            initial_biomass,
            respiration_cost,
            leaflets_biomass_contribution,
            rachis_biomass_contribution,
            petiole_biomass_contribution,
        )
    end
end

function LeafBiomass(
    initial_biomass,
    respiration_cost,
    leaflets_biomass_contribution,
    rachis_biomass_contribution,
    petiole_biomass_contribution,
)
    values = promote(
        initial_biomass,
        respiration_cost,
        leaflets_biomass_contribution,
        rachis_biomass_contribution,
        petiole_biomass_contribution,
    )
    LeafBiomass{typeof(first(values))}(values...)
end

LeafBiomass(initial_biomass, respiration_cost) =
    LeafBiomass(initial_biomass, respiration_cost, 0.30, 0.30, 0.40)

LeafBiomass(;
    initial_biomass=0.0,
    respiration_cost=1.44,
    leaflets_biomass_contribution=0.30,
    rachis_biomass_contribution=0.30,
    petiole_biomass_contribution=0.40,
) = LeafBiomass(
    initial_biomass,
    respiration_cost,
    leaflets_biomass_contribution,
    rachis_biomass_contribution,
    petiole_biomass_contribution,
)

PlantSimEngine.inputs_(::LeafBiomass) = (
    carbon_allocation=PlantSimEngine.Default(0.0),
)
PlantSimEngine.outputs_(m::LeafBiomass) = (
    biomass=m.initial_biomass,
    biomass_leaflets=m.initial_biomass * m.leaflets_biomass_contribution,
    biomass_rachis=m.initial_biomass * m.rachis_biomass_contribution,
    biomass_petiole=m.initial_biomass * m.petiole_biomass_contribution,
)
PlantSimEngine.variable_contracts_(::LeafBiomass) = (
    carbon_allocation=_DAILY_CH2O_EQUIVALENT_FLOW,
    biomass=_STRUCTURAL_DRY_MASS,
    biomass_leaflets=_STRUCTURAL_DRY_MASS,
    biomass_rachis=_STRUCTURAL_DRY_MASS,
    biomass_petiole=_STRUCTURAL_DRY_MASS,
)

# Applied at the leaf scale:
function PlantSimEngine.run!(m::LeafBiomass, st, environment, constants, context=nothing)
    st.biomass += st.carbon_allocation / m.respiration_cost
    st.biomass_leaflets = st.biomass * m.leaflets_biomass_contribution
    st.biomass_rachis = st.biomass * m.rachis_biomass_contribution
    st.biomass_petiole = st.biomass * m.petiole_biomass_contribution
end
