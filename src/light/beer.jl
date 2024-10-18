"""
    Beer(k)

Beer-Lambert law for light interception.

# Arguments

- `k`: extinction coefficient of light

# Inputs 

- `lai` in m² m⁻².

# Required meteorology data

- `Ri_PAR_f`: incident flux of atmospheric radiation in the PAR, in MJ m⁻² d⁻¹.

# Outputs

- `aPPFD`: absorbed Photosynthetic Photon Flux Density in mol[PAR] m[soil]⁻² d⁻¹.
"""
struct Beer{T} <: AbstractLight_InterceptionModel
    k::T
end

Beer(; k=0.6) = Beer(k)

function PlantSimEngine.inputs_(::Beer)
    (lai=-Inf,)
end

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
    status.aPPFD = # in mol[PAR] m[soil]⁻² d⁻¹
        meteo.Ri_PAR_f * # in MJ m[soil]⁻² d⁻¹
        (1.0 - exp(-models.light_interception.k * status.lai)) *
        constants.J_to_umol
end


"""
    SceneToPlantLightPartitioning()

Partitioning from aPPFD at the scene scale to the plant scale based on the relative 
leaf area of the plant.

# Inputs 

- `aPPFD`: absorbed Photosynthetic Photon Flux Density in mol[PAR] m[soil]⁻² d⁻¹ (scene scale).
- `plant_leaf_area`: the target plant leaf area
- `scene_leaf_area`: the total scene leaf area

# Outputs

- `aPPFD_plant`: absorbed Photosynthetic Photon Flux Density in mol[PAR] plant⁻¹ s⁻¹.
"""
struct SceneToPlantLightPartitioning <: AbstractLight_InterceptionModel end

function PlantSimEngine.inputs_(::SceneToPlantLightPartitioning)
    (aPPFD=-Inf, plant_leaf_area=-Inf, scene_leaf_area=-Inf)
end

function PlantSimEngine.outputs_(::SceneToPlantLightPartitioning)
    (aPPFD_plant=-Inf,)
end

# Partitioning between plants:
function PlantSimEngine.run!(::SceneToPlantLightPartitioning, models, status, meteo, constants, extra=nothing)
    # aPPFD in mol[PAR] plant⁻¹ d⁻¹, from aPPFD in mol[PAR] m[soil]⁻² d⁻¹ and the plant's relative leaf area:
    status.aPPFD_plant = status.aPPFD * status.plant_leaf_area / status.scene_leaf_area
end