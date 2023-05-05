module XPalm

import MultiScaleTreeGraph
import MultiScaleTreeGraph: NodeMTG, addchild!
import Dates
import PlantSimEngine
import PlantMeteo
import PlantSimEngine: @process

include("soil/FTSW.jl")
include("meteo/ThermalTime.jl")
include("plant/root_growth.jl")

# include("structs.jl")
# include("add_organ.jl")
# include("reproductive_organs.jl")
# include("respiration/maintenance/maintenance_respiration.jl")
# include("respiration/maintenance/Q10.jl")
# include("model_definition.jl")

export Palm

# exports for prototyping
export FTSW, soil_init_default
export ThermalTime
export RootGrowth
end