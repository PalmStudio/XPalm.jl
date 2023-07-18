"""
    Beer(k)

Beer-Lambert law for light interception.

# Arguments

- `k`: extinction coefficient of light


Required inputs: `LAI` in m² m⁻².
Required meteorology data: `Ri_PAR_f`, the incident flux of atmospheric radiation in the
PAR, in W m[soil]⁻² (== J m[soil]⁻² s⁻¹).

Output: aPPFD, the absorbed Photosynthetic Photon Flux Density in μmol[PAR] m[leaf]⁻² s⁻¹.
"""
struct Beer{T,O} <: AbstractLight_InterceptionModel
    k::T
end

Beer{O}(k::T=0.6) where {O,T} = Beer{T,O}(k)
Beer(k::T=0.6) where {T} = Beer{T,Any}(k)

function PlantSimEngine.inputs_(::Beer)
    (lai=-Inf,)
end

function PlantSimEngine.inputs_(::Beer{T,Plant}) where {T}
    (leaf_area=-Inf,)
end

PlantSimEngine.inputs_(::Beer{T,Soil}) where {T} = NamedTuple()

function PlantSimEngine.outputs_(::Beer)
    (aPPFD=-Inf,)
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:Beer}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:Beer}) = PlantSimEngine.IsTimeStepIndependent()

"""
    run!(object, meteo, constants = Constants())

Computes the light interception of an object using the Beer-Lambert law.

# Arguments

- `::Beer`: a Beer model, from the model list (*i.e.* m.light_interception)
- `models`: A `ModelList` struct holding the parameters for the model with
initialisations for `lai` (m² m⁻²): the leaf area index.
- `status`: the status of the model, usually the model list status (*i.e.* m.status)
- `meteo`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Examples

```julia
using PlantSimEngine, PlantBiophysics, PlantMeteo
m = ModelList(light_interception=Beer(0.5), status=(lai=2.0,))

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)
run!(m, meteo)
m[:aPPFD]
```
"""
function PlantSimEngine.run!(m::Beer, models, status, meteo, constants, extra=nothing)
    status.aPPFD =
        meteo.Ri_PAR_f *
        (1 - exp(-m.k * status.lai)) *
        constants.J_to_umol
end

# At the plant scale
function PlantSimEngine.run!(::Beer{T,Plant}, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node) where {T}
    rn = max(1, rownumber(status) - 1) # take the row number (cannot be < 1)

    scene_node = get_root(mtg)
    plant_leaf_area = Vector{typeof(status.leaf_area)}()
    MultiScaleTreeGraph.traverse!(scene_node, symbol="Plant") do node
        push!(plant_leaf_area, node[:models].status[rn][:leaf_area])
    end

    relative_leaf_area = mtg[:models].status[rn].leaf_area / sum(plant_leaf_area)

    # aPPFD in MJ d-1 plant-1:
    status.aPPFD =
        scene_node[:models].status[rn].aPPFD *
        scene_node[:area] *
        relative_leaf_area
end

# At the soil scale:
function PlantSimEngine.run!(::Beer{T,Soil}, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node) where {T}
    timestep = rownumber(status)
    status.aPPFD = get_root(mtg)[:models].status[timestep].aPPFD
end