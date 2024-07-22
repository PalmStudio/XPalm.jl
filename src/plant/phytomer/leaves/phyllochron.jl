struct PhyllochronModel{I,T} <: AbstractPhyllochronModel
    age_palm_maturity::I
    threshold_ftsw_stress::T
    production_speed_initial::T
    production_speed_mature::T
    ini_phytomer::I
end

PlantSimEngine.inputs_(::PhyllochronModel) = (
    plant_age=0,
    TEff=-Inf,
    ftsw=-Inf,
)

PlantSimEngine.outputs_(m::PhyllochronModel) = (
    newPhytomerEmergence=0.0,
    phyllochron=-Inf,
    production_speed=-Inf,
    phylo_slow=-Inf,
    phytomers=m.ini_phytomer,
)

PlantSimEngine.dep(::PhyllochronModel) = (phytomer_emission=AbstractPhytomer_EmissionModel,)

# Applied at the plant scale.
function PlantSimEngine.run!(m::PhyllochronModel, models, status, meteo, constants, extra=nothing)
    status.production_speed = age_relative_value(
        status.plant_age,
        0.0,
        m.age_palm_maturity,
        m.production_speed_initial,
        m.production_speed_mature
    )

    status.phylo_slow = status.ftsw > m.threshold_ftsw_stress ? 1 : status.ftsw / m.threshold_ftsw_stress

    status.newPhytomerEmergence += status.TEff * status.production_speed * status.phylo_slow

    if status.newPhytomerEmergence >= 1.0
        status.newPhytomerEmergence -= 1.0 # NB: -=1 because it can be > 1 so we pass along the remainder
        status.phytomers += 1
        # Add a new phytomer to the palm using a phytomer emission model:
        PlantSimEngine.run!(models.phytomer_emission, models, status, meteo, constants, extra)
    end
end