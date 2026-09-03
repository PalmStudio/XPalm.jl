PlantSimEngine.@process "fresh_biomass" verbose = false

const _VPALM_STRUCTURAL_DRY_MASS = PlantSimEngine.VariableContract(
    unit=:g_dry_matter,
    basis=:object,
    aggregation=:state,
    extent=:extensive,
)

const _VPALM_CH2O_EQUIVALENT_STOCK = PlantSimEngine.VariableContract(
    unit=:g_ch2o_equivalent,
    basis=:object,
    aggregation=:state,
    extent=:extensive,
)

const _VPALM_FRESH_MASS = PlantSimEngine.VariableContract(
    unit=:kg_fresh_matter,
    basis=:object,
    aggregation=:state,
    extent=:extensive,
)

"""
    LeafFreshBiomass(
        leaflets_dry_matter_fraction,
        rachis_dry_matter_fraction,
        petiole_dry_matter_fraction,
        reserve_to_dry_mass=1.0,
    )

Convert the leaf masses simulated by XPalm into the fresh masses required by
VPalm's biomechanical model.

XPalm keeps structural dry mass and non-structural carbohydrate reserve as
separate state variables. The reserve is first converted to a dry-mass
equivalent and distributed among leaflets, rachis and petiole in proportion to
their non-negative structural dry masses. Each resulting organ dry mass is
then divided by its observed dry-matter fraction.

`reserve_to_dry_mass` is expressed in gDM-equivalent per g CH2O-equivalent.
Its default value of one makes explicit the equivalence already used by
`PotentialReserveLeaf`, whose capacity is computed directly from a difference
in LMA. It is a mass conversion, not a construction or mobilization cost.

# Inputs

- `biomass_leaflets`: structural leaflet dry mass (gDM)
- `biomass_rachis`: structural rachis dry mass (gDM)
- `biomass_petiole`: structural petiole dry mass (gDM)
- `reserve`: leaf non-structural carbohydrate reserve (g CH2O-equivalent)

# Outputs

- `fresh_biomass_leaflets`: leaflet fresh mass (kgFM)
- `fresh_biomass_rachis`: rachis fresh mass (kgFM)
- `fresh_biomass_petiole`: petiole fresh mass (kgFM)
"""
struct LeafFreshBiomass{T<:AbstractFloat} <: AbstractFresh_BiomassModel
    leaflets_dry_matter_fraction::T
    rachis_dry_matter_fraction::T
    petiole_dry_matter_fraction::T
    reserve_to_dry_mass::T

    function LeafFreshBiomass{T}(
        leaflets_dry_matter_fraction::T,
        rachis_dry_matter_fraction::T,
        petiole_dry_matter_fraction::T,
        reserve_to_dry_mass::T,
    ) where {T}
        dry_matter_fractions = (
            leaflets_dry_matter_fraction,
            rachis_dry_matter_fraction,
            petiole_dry_matter_fraction,
        )
        all(
            fraction -> isfinite(fraction) &&
                        zero(fraction) < fraction <= one(fraction),
            dry_matter_fractions,
        ) ||
            throw(ArgumentError("leaf dry-matter fractions must be in (0, 1]"))
        isfinite(reserve_to_dry_mass) &&
            reserve_to_dry_mass >= zero(reserve_to_dry_mass) ||
            throw(ArgumentError("reserve_to_dry_mass must be non-negative"))
        new{T}(
            leaflets_dry_matter_fraction,
            rachis_dry_matter_fraction,
            petiole_dry_matter_fraction,
            reserve_to_dry_mass,
        )
    end
end

function LeafFreshBiomass(
    leaflets_dry_matter_fraction,
    rachis_dry_matter_fraction,
    petiole_dry_matter_fraction,
    reserve_to_dry_mass=1.0,
)
    values = promote(
        float(leaflets_dry_matter_fraction),
        float(rachis_dry_matter_fraction),
        float(petiole_dry_matter_fraction),
        float(reserve_to_dry_mass),
    )
    return LeafFreshBiomass{typeof(first(values))}(values...)
end

LeafFreshBiomass(;
    leaflets_dry_matter_fraction,
    rachis_dry_matter_fraction,
    petiole_dry_matter_fraction,
    reserve_to_dry_mass=1.0,
) = LeafFreshBiomass(
    leaflets_dry_matter_fraction,
    rachis_dry_matter_fraction,
    petiole_dry_matter_fraction,
    reserve_to_dry_mass,
)

PlantSimEngine.inputs_(::LeafFreshBiomass) = (
    biomass_leaflets=PlantSimEngine.Required(Real),
    biomass_rachis=PlantSimEngine.Required(Real),
    biomass_petiole=PlantSimEngine.Required(Real),
    reserve=PlantSimEngine.Required(Real),
)

PlantSimEngine.outputs_(model::LeafFreshBiomass) = (
    fresh_biomass_leaflets=zero(model.leaflets_dry_matter_fraction),
    fresh_biomass_rachis=zero(model.rachis_dry_matter_fraction),
    fresh_biomass_petiole=zero(model.petiole_dry_matter_fraction),
)

PlantSimEngine.variable_contracts_(::LeafFreshBiomass) = (
    biomass_leaflets=_VPALM_STRUCTURAL_DRY_MASS,
    biomass_rachis=_VPALM_STRUCTURAL_DRY_MASS,
    biomass_petiole=_VPALM_STRUCTURAL_DRY_MASS,
    reserve=_VPALM_CH2O_EQUIVALENT_STOCK,
    fresh_biomass_leaflets=_VPALM_FRESH_MASS,
    fresh_biomass_rachis=_VPALM_FRESH_MASS,
    fresh_biomass_petiole=_VPALM_FRESH_MASS,
)

function PlantSimEngine.run!(
    model::LeafFreshBiomass,
    status,
    environment,
    constants,
    context=nothing,
)
    biomass_leaflets = max(zero(status.biomass_leaflets), status.biomass_leaflets)
    biomass_rachis = max(zero(status.biomass_rachis), status.biomass_rachis)
    biomass_petiole = max(zero(status.biomass_petiole), status.biomass_petiole)
    structural_dry_mass =
        biomass_leaflets + biomass_rachis + biomass_petiole

    if structural_dry_mass <= zero(structural_dry_mass)
        status.fresh_biomass_leaflets = zero(status.fresh_biomass_leaflets)
        status.fresh_biomass_rachis = zero(status.fresh_biomass_rachis)
        status.fresh_biomass_petiole = zero(status.fresh_biomass_petiole)
        return nothing
    end

    reserve_dry_mass =
        max(zero(status.reserve), status.reserve) * model.reserve_to_dry_mass
    gravitational_scale =
        one(structural_dry_mass) + reserve_dry_mass / structural_dry_mass

    # Input masses are grams and VPalm expects kilograms.
    status.fresh_biomass_leaflets =
        biomass_leaflets * gravitational_scale /
        (1000 * model.leaflets_dry_matter_fraction)
    status.fresh_biomass_rachis =
        biomass_rachis * gravitational_scale /
        (1000 * model.rachis_dry_matter_fraction)
    status.fresh_biomass_petiole =
        biomass_petiole * gravitational_scale /
        (1000 * model.petiole_dry_matter_fraction)

    return nothing
end
