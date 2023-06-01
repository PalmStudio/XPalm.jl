struct PhyllochronModel <: AbstractPhyllochronModel
    age_palm_maturity
    threshold_ftsw_stress
    production_speed_initial
    production_speed_mature
end

PlantSimEngine.inputs_(::PhyllochronModel) = (
    plant_age=-9999,
    TEff=-Inf,
    ftsw=-Inf,
)

PlantSimEngine.outputs_(::PhyllochronModel) = (
    newPhytomerEmergence=-Inf,
    phyllochron=-Inf,
    production_speed=-Inf,
    phylo_slow=-Inf,
    phytomers=-Inf,
)

# Applied at the plant scale.
function PlantSimEngine.run!(m::PhyllochronModel, models, status, meteo, constants, mtg)
    status.production_speed = age_relative_value(
        status.plant_age,
        0.0,
        m.age_palm_maturity,
        m.production_speed_initial,
        m.production_speed_mature
    )

    status.phylo_slow = status.ftsw > m.threshold_ftsw_stress ? 1 : status.ftsw / m.threshold_ftsw_stress

    status.newPhytomerEmergence =
        prev_value(status, :newPhytomerEmergence; default=0.0) +
        status.TEff * status.production_speed * status.phylo_slow

    status.phytomers = prev_value(status, :phytomers, default=status.phytomers)

    if status.newPhytomerEmergence >= 1.0
        status.newPhytomerEmergence -= 1.0 # NB: -=1 because it can be > 1 so we pass along the remainder
        status.phytomers += 1
        # Add a new phytomer to the palm using a phytomer emission model:
        PlantSimEngine.run!(models.phytomer_emission, models, status, meteo, constants, mtg)
    end
end