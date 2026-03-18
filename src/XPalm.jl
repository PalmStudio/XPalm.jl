module XPalm

import MultiScaleTreeGraph: Node, NodeMTG, index, symbol#, get_root
import PlantSimEngine
import PlantSimEngine: MultiScaleModel, PreviousTimeStep
import Random
import Dates
import Tables
import OrderedCollections: OrderedDict

# Palm structure:
include("plant/mtg/structs.jl")

include("age_modulation/age_modulation_linear.jl")
include("age_modulation/age_modulation_logistic.jl")

# Load all models from the Models module:
include("XPalmModels.jl")
using .Models

# Load VPalm for reconstruction of the palm structure:
include("VPalm.jl")
using .VPalm

include("model_definition.jl")

include("run.jl")
include("notebook.jl")

export xpalm
end
