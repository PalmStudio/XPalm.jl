# XPalm uses daily-integrated PAR throughout its Beer, partitioning, RUE, and
# FTSW chain. Runtime values remain ordinary numbers; these contracts make the
# spatial and temporal meaning of `aPPFD` explicit at compilation time.
const _GROUND_DAILY_PAR_PHOTONS = PlantSimEngine.VariableContract(
    unit=:mol_photon,
    basis=:ground_area,
    temporal=:day,
    aggregation=:total,
    extent=:intensive,
)

const _PLANT_DAILY_PAR_PHOTONS = PlantSimEngine.VariableContract(
    unit=:mol_photon,
    basis=:plant,
    temporal=:day,
    aggregation=:total,
    extent=:extensive,
)
