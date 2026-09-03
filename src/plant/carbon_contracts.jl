# XPalm's carbon-source, maintenance, demand, allocation, and reserve
# calculations use carbohydrate-equivalent mass. This matches the units of the
# source parameters inherited from Dufrêne, van Kraalingen, Combres, and
# PALMSIM: g CH2O-equivalent rather than elemental g C.
#
# The object basis covers both plant totals and per-organ distributed values:
# PlantSimEngine's object/application routing carries the concrete scale.
const _DAILY_CH2O_EQUIVALENT_FLOW = PlantSimEngine.VariableContract(
    unit=:g_ch2o_equivalent,
    basis=:object,
    temporal=:day,
    aggregation=:total,
    extent=:extensive,
)

const _CH2O_EQUIVALENT_STOCK = PlantSimEngine.VariableContract(
    unit=:g_ch2o_equivalent,
    basis=:object,
    aggregation=:state,
    extent=:extensive,
)

const _ACCUMULATED_CH2O_EQUIVALENT = PlantSimEngine.VariableContract(
    unit=:g_ch2o_equivalent,
    basis=:object,
    aggregation=:accumulated,
    extent=:extensive,
)

const _STRUCTURAL_DRY_MASS = PlantSimEngine.VariableContract(
    unit=:g_dry_matter,
    basis=:object,
    aggregation=:state,
    extent=:extensive,
)
