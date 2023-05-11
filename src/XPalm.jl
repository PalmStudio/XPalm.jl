module XPalm

import MultiScaleTreeGraph
import MultiScaleTreeGraph: NodeMTG, addchild!
import Dates
import PlantSimEngine
import PlantMeteo
import PlantSimEngine: @process

include("soil/FTSW.jl")
include("meteo/thermal_time.jl")
include("meteo/et0_BP.jl")
include("plant/roots/root_growth.jl")


# include("structs.jl")
# include("add_organ.jl")
# include("reproductive_organs.jl")
# include("respiration/maintenance/maintenance_respiration.jl")
# include("respiration/maintenance/Q10.jl")
# include("model_definition.jl")

export Palm

# exports for prototyping
export FTSW, soil_init_default
export DailyDegreeDays
export RootGrowth
export ET0_BP
end