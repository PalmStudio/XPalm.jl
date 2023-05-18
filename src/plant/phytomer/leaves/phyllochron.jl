struct PhyllochronModel <: AbstractPhyllochronModel
    age_palm_maturity
    treshold_ftsw_stress
    production_speed_initial
    production_speed_mature
end

PlantSimEngine.inputs_(::PhyllochronModel) = (
    plant_age=-9999,
    TEff=-Inf,
    ftsw=-Inf,
    phytomer_count=-9999,
)

PlantSimEngine.outputs_(::PhyllochronModel) = (
    newPhytomerEmergence=-Inf,
    phyllochron=-Inf,
)

# Applied at the plant scale.
function PlantSimEngine.run!(m::PhyllochronModel, models, status, meteo, constants, mtg)
    production_speed = age_relative_var(
        status.plant_age,
        0.0,
        m.age_palm_maturity,
        m.production_speed_initial,
        m.production_speed_mature
    )

    phylo_slow = status.ftsw > m.treshold_ftsw_stress ? 1 : status.ftsw / m.treshold_ftsw_stress

    status.newPhytomerEmergence =
        PlantMeteo.prev_value(status, :newPhytomerEmergence; default=0.0) +
        status.TEff * production_speed * phylo_slow

    status.phytomer_count = PlantMeteo.prev_value(
        status,
        :phytomer_count;
        default=status.phytomer_count # default to the initialisation value
    )

    if status.newPhytomerEmergence >= 1.0
        status.newPhytomerEmergence -= 1.0 # NB: -=1 because it can be > 1 so we pass along the remainder
        # Add a new phytomer to the palm using a phytomer emission model:
        PlantSimEngine.run!(models.phytomer_emission, models, status, meteo, constants, mtg)
    end
end