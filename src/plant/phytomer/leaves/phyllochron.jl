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

"""
struct PhyllochronModel{I,T} <: AbstractPhyllochronModel
    age_palm_maturity::I
    threshold_ftsw_stress::T
    production_speed_initial::T
    production_speed_mature::T
end

function PhyllochronModel(; age_palm_maturity=2920, threshold_ftsw_stress=0.3, production_speed_initial=0.0111, production_speed_mature=0.0074)
    PhyllochronModel(age_palm_maturity, threshold_ftsw_stress, production_speed_initial, production_speed_mature)
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
        # Add a new phytomer to the palm using a phytomer emission model:
        PlantSimEngine.run!(models.phytomer_emission, models, status, meteo, constants, extra)
    end
end