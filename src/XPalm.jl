module XPalm

import MultiScaleTreeGraph
import MultiScaleTreeGraph: NodeMTG, addchild!
import Dates
import PlantBiophysics

include("structs.jl")
include("add_organ.jl")
include("reproductive_organs.jl")

export Palm

end