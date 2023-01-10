"""
    RmQ10{O}(Q10) where O <: Organ

Maintenance respiration.

# Arguments

- `Q10`: Q10 factor (values should usually range between: 1.5 - 2.5, with 2.1 being the most common value)
- `Rm_base`: Base maintenance respiration (gC gDM⁻¹ d⁻¹). Should be around 0.06.
- `T_ref`: Reference temperature at which Q10 was measured (default: 25.0°C)

# Examples
    
```julia
RmQ10{Leaf}(1.5, 0.06, 25.0)
```
"""
struct RmQ10{O,T} <: PlantSimEngine.AbstractModel where {O<:Organ,T}
    Q10::T
    Rm_base::T
    T_ref::T
end

RmQ10{O}(Q10, Rm_base, T_ref=25.0) where {O<:Organ} = RmQ10{O,typeof(Q10)}(Q10, Rm_base, T_ref)

PlantSimEngine.inputs_(::RmQ10) = (
    biomass_dry=-Inf,
    temperature=-Inf,
    nitrogen_content=-Inf, # Organ nitrogen content (gN gDM-1). Leaves are around 2-3% N, fruits ~1%, stems ~0.5%.
)

PlantSimEngine.outputs_(::RmQ10) =
    (
        Rm=-Inf,
    )
# dep(::FTSW) = (test_prev=AbstractTestPrevModel,)

# Inputs are different for a Plant type (we sum-up the phytomers Rm):
PlantSimEngine.inputs_(::RmQ10{Plant,T}) where {T} = NamedTuple()

# Idem for the Phytomer, it is the sum of Internode, Leaf and Reproductive organ
PlantSimEngine.inputs_(::RmQ10{Phytomer,T}) where {T} = NamedTuple()

function maintenance_respiration!_(::RmQ10{Phytomer,T} where {T}, models, status, meteo, constants, node)
    # We sum the Rm of the internode, leaf and reproductive organs:
    status.Rm = 0.0
    for node in MultiScaleTreeGraph.children(node)
        st_ = node[:models][1]
        length(st_.Rm) > 1 && error("`maintenance_respiration` is only compatible for status of one time-step.")
        status.Rm += st_[:Rm]
    end
end

function maintenance_respiration!_(::RmQ10{Plant,T} where {T}, models, status, meteo, constants, node)

    Rm_organs = MultiScaleTreeGraph.traverse(
        node,
        x -> status(x, :Rm),
        scale=4
    )

    if length(Rm_organs) == 0
        error("No maintenance respiration found for the organs at scale 4 in the plant.")
    end

    status.Rm = sum(Rm_organs)

    return nothing
end

# Standard way of computing the Rm of an organ:
function maintenance_respiration!_(::RmQ10{O,T}, models, status, meteo, constants, node) where {O,T}
    status.Rm =
        status.biomass_dry * status.nitrogen_content * models.maintenance_respiration.Rm_base *
        models.maintenance_respiration.Q10^((status.temperature - models.maintenance_respiration.T_ref) / 10.0)
end

# We don't compute the Rm of the Male inflorescence:
function maintenance_respiration!_(::RmQ10{Male,T} where {T}, models, status, meteo, constants, node)
    nothing
end