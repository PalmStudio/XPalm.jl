module XPalm

import MultiScaleTreeGraph
import MultiScaleTreeGraph: NodeMTG, addchild!
import Dates
import PlantSimEngine
import PlantBiophysics
import PlantMeteo

include("structs.jl")
include("add_organ.jl")
include("reproductive_organs.jl")
include("respiration/maintenance.jl")
include("model_definition.jl")

export Palm

end