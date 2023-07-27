"""
PhyllochronModel(age_palm_maturity,threshold_ftsw_stress,production_speed_initial,production_speed_mature)

Compute the phyllochron and initiate a new phytomer at every new emergence

# Arguments
- `age_palm_maturity`: age of the plant when maturity is establiched (days)
- `threshold_ftsw_stress`:ftsw treshold below which the phyllochron is reduce
- `production_speed_initial`: initial phyllochron (for seedlings) (leaf.degreeC days-1)
- `production_speed_mature`: phyllochron at plant maturity (leaf.degreeC days-1)

# Inputs
- `plant_age`= plant age (days)
- `TEff`: daily efficient temperature for plant growth (degree C days) 
- `ftsw`= fraction of tranpirable soil water (unitless)

# Outputs 
- `newPhytomerEmergence`: fraction of time during two successive phytomer (at 1 the new phytomer emerge)
- `production_speed`= phyllochron at the current plant age (leaf.degreeC days-1)
- `phylo_slow`= coefficient of reduction of the phyllochron du to ftsw
- `phytomers`= number of phytomers emmitted since simulation starts

"""
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