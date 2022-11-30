"""
    RmQ10{O}(Q10) where O <: Organ

Maintenance respiration of an organ.

# Examples
    
```julia
RmQ10{Leaf}(1.5)
```
"""
struct RmQ10{O,T} <: PlantSimEngine.AbstractModel where {O<:Organ,T}
    Q10::T
    node::MultiScaleTreeGraph.Node
end

RmQ10{O}(Q10, node) where {O<:Organ} = RmQ10{O,typeof(Q10)}(Q10, node)

PlantSimEngine.inputs_(::RmQ10) = (
    biomass_dry=-Inf,
    temperature=-Inf,
)

PlantSimEngine.outputs_(::RmQ10) =
    (
        Rm=-Inf,
    )
# dep(::FTSW) = (test_prev=AbstractTestPrevModel,)

# Inputs are different for a Plant type (we need the 
# node to go and search for phytomer Rm and sum it)
PlantSimEngine.inputs_(::RmQ10{Plant,T}) where {T} = (
    node=-Inf,
)

# Idem for the Phytomer, it is the sum of Internode, Leaf and Reproductive organ
PlantSimEngine.inputs_(::RmQ10{Phytomer,T}) where {T} = (
    node=-Inf,
)

function Rm!_(::RmQ10{Phytomer,T} where {T}, models, status, meteo::PlantMeteo.AbstractAtmosphere, constants)
    # We sum the Rm of the internode, leaf and reproductive organs:
    status.Rm = 0.0
    for node in MultiScaleTreeGraph.children(constants.node)
        status.Rm += status.node.models[:Rm]
    end
end

function Rm!_(::RmQ10{Plant,T} where {T}, models, status, meteo::PlantMeteo.AbstractAtmosphere, constants)
    MultiScaleTreeGraph.tarverse
    status.Rm = sum(MultiScaleTreeGraph.descendants(constants.node, :Rm, scale=4, all=false, type=Float64))
end

function Rm!_(::RmQ10{Leaf,T} where {T}, models, status, meteo::PlantMeteo.AbstractAtmosphere, constants)
    # The code here
end


function Rm!_(::RmQ10{Male,T} where {T}, models, status, meteo::PlantMeteo.AbstractAtmosphere, constants=Constants())
    # The code here
end