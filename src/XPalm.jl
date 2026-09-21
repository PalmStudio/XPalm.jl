module XPalm

import MultiScaleTreeGraph
import MultiScaleTreeGraph: Node, NodeMTG, index, symbol, node_attributes#, get_root
import PlantSimEngine
import PlantSimEngine: PreviousTimeStep
import Random
import Dates
import Tables
import OrderedCollections: OrderedDict

include("vpalm/IO/parameter_normalization.jl")
include("vpalm_parameters.jl")

# Define architecture methods before any user function can call them. Including
# the module inside Palm/model_applications creates methods newer than that caller.
# VPalm uses declared dependencies and creates no renderer or display window.
include("VPalm.jl")

load_vpalm!() = VPalm

# Palm structure:
include("plant/mtg/structs.jl")

include("age_modulation/age_modulation_linear.jl")
include("age_modulation/age_modulation_logistic.jl")

# Load all models from the Models module:
include("XPalmModels.jl")
using .Models

include("model_definition.jl")

include("run.jl")
include("notebook.jl")

export xpalm, xpalm_scene, model_applications, load_vpalm!
end
