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

function load_vpalm!()
    isdefined(@__MODULE__, :VPalm) || Base.include(@__MODULE__, joinpath(@__DIR__, "VPalm.jl"))
    return Base.invokelatest(getfield, @__MODULE__, :VPalm)
end

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
