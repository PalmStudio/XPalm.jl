module XPalm

import MultiScaleTreeGraph
import MultiScaleTreeGraph: NodeMTG, addchild!
import Dates
import PlantSimEngine
import PlantMeteo
import PlantSimEngine: @process

# Import the processes:
include("soil/0-process.jl")
include("plant/roots/0-process.jl")

# Import the models:
include("soil/FTSW.jl")
include("meteo/thermal_time.jl")
include("meteo/et0_BP.jl")
include("plant/roots/root_growth.jl")


include("plant/mtg/structs.jl")
include("plant/mtg/add_organ.jl")
include("plant/respiration/maintenance/maintenance_respiration.jl")
include("plant/respiration/maintenance/Q10.jl")
include("model_definition.jl")

include("age_modulation/age_modulation_linear.jl")
include("age_modulation/age_modulation_logistic.jl")

export Palm

# exports for prototyping
export FTSW, soil_init_default
export DailyDegreeDays
export RootGrowthFTSW
export ET0_BP
end