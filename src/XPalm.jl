module XPalm

import MultiScaleTreeGraph
import MultiScaleTreeGraph: NodeMTG, addchild!
import Dates
import PlantSimEngine
import PlantMeteo
import PlantMeteo: prev_value, rownumber
import PlantSimEngine: @process
import Tables
import Statistics: mean
import Random: MersenneTwister

# Palm structure:
include("plant/mtg/structs.jl")

# Import the processes:
include("light/0-process.jl")
include("soil/0-process.jl")
include("plant/plant_age/0-process.jl")
include("plant/roots/0-process.jl")
include("plant/phytomer/phytomer/0-process.jl")
include("plant/phytomer/leaves/0-process.jl")
include("plant/phytomer/internode/0-process.jl")
include("plant/generic_processes/0-process.jl")
include("plant/reserves/0-process.jl")
include("plant/phytomer/ReproductiveOrgans/Male/0-process.jl")
include("plant/phytomer/fruits/0-process.jl")

# Import the models:
include("meteo/thermal_time.jl")
include("meteo/thermal_time_ftsw.jl")
include("meteo/et0_BP.jl")

include("light/beer.jl")
include("plant/plant_age/palm_age_increment.jl")
include("plant/plant_age/initiation_age.jl")
include("soil/FTSW.jl")
include("soil/FTSW_BP.jl")
include("plant/roots/root_growth.jl")

include("plant/phytomer/phytomer/add_phytomer.jl")
include("plant/phytomer/leaves/phyllochron.jl")
include("plant/phytomer/leaves/final_potential_area.jl")
include("plant/phytomer/leaves/potential_area.jl")
include("plant/phytomer/leaves/leaf_area.jl")
include("plant/phytomer/leaves/lai.jl")
include("plant/phytomer/leaves/state.jl")
include("plant/phytomer/leaves/leaf_rank.jl")
include("plant/phytomer/leaves/leaf_pruning.jl")
include("plant/phytomer/leaves/carbon_demand.jl")
include("plant/phytomer/leaves/biomass.jl")
include("plant/reserves/reserve_filling_leaf_only.jl")
include("plant/reserves/reserve_filling_leaf_and_stem.jl")

# Internode:
include("plant/phytomer/internode/final_potential_dimension.jl")
include("plant/phytomer/internode/potential_dimensions.jl")
include("plant/phytomer/internode/carbon_demand.jl")
include("plant/phytomer/internode/biomass.jl")
include("plant/phytomer/internode/actual_dimension.jl")

# Stem:
include("plant/stem/biomass.jl")

include("plant/carbon_assimilation/rue.jl")
include("plant/carbon_offer/carbon_offer_photosynthesis.jl")
include("plant/carbon_offer/carbon_offer_rm.jl")
include("plant/carbon_allocation/carbon_allocation.jl")
include("plant/respiration/maintenance/maintenance_respiration.jl")
include("plant/respiration/maintenance/Q10.jl")
include("model_definition.jl")

include("age_modulation/age_modulation_linear.jl")
include("age_modulation/age_modulation_logistic.jl")

# inflorescences:
include("plant/phytomer/phytomer/sex_determination.jl")
include("plant/phytomer/phytomer/abortion.jl")

# male
include("plant/phytomer/ReproductiveOrgans/Male/biomass.jl")
include("plant/phytomer/ReproductiveOrgans/Male/state.jl")
include("plant/phytomer/ReproductiveOrgans/Male/carbon_demand.jl")
include("plant/phytomer/ReproductiveOrgans/Male/final_potential_biomass.jl")

include("plant/phytomer/phytomer/add_reproductive_organ.jl")
include("plant/phytomer/fruits/reproductive_development.jl")

include("run.jl")



export Palm

# exports for prototyping
export FTSW, FTSW_BP, soil_init_default
export DailyDegreeDays
export RootGrowthFTSW
export ET0_BP
end