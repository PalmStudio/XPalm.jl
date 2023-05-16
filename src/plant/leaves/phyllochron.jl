struct PhyllochronModel <: AbstractPhyllochronModel
    age_palm_maturity
    treshold_ftsw_stress
    production_speed_initial
    production_speed_mature
end

PlantSimEngine.inputs_(::Type{PhyllochronModel}) = (
    age_palm=-9999,
    ftsw=-Inf,
)

PlantSimEngine.outputs_(::Type{PhyllochronModel}) = (
    newPhytomerEmergence=-Inf,
    phyllochron=-Inf,
)

function run!(m::PhyllochronModel, models, status, meteo, constants, mtg)
    production_speed = age_relative_var(
        status.age_palm,
        0.0,
        m.age_palm_maturity,
        m.production_speed_initial,
        m.production_speed_mature
    )

    phylo_slow = status.ftsw > m.treshold_ftsw_stress ? 1 : status.ftsw / m.treshold_ftsw_stress


    PlantMeteo.prev_value(status, :root_depth; default=m.ini_root_depth)

    status.newPhytomerEmergence =
        PlantMeteo.prev_value(status, :newPhytomerEmergence; default=0.0) +
        status.TEff * production_speed * phylo_slow

    if status.newPhytomerEmergence >= 1.0
        total_phytomer_number += 1.0
        newPhytomer += 1.0
        status.newPhytomerEmergence -= 1.0 # NB: -=1 because it can be > 1 so we pass along the remainder
        create_phytomer(t, newPhytomer, newPhytomer, age)
    end
end