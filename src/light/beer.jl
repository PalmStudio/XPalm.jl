"""
    Beer(k)

Beer-Lambert law for light interception.

# Arguments

- `k`: extinction coefficient of light

# Inputs 

- `lai` in m² m⁻².

# Environment inputs

- `Ri_PAR_f`: incident flux of atmospheric radiation in the PAR, in MJ m⁻² d⁻¹.

# Outputs

- `aPPFD`: absorbed Photosynthetic Photon Flux Density in mol[PAR] m[soil]⁻² d⁻¹.
"""
struct Beer{T} <: AbstractLight_InterceptionModel
    k::T
end

Beer(; k=0.6) = Beer(k)

function PlantSimEngine.inputs_(::Beer)
    (lai=PlantSimEngine.Required(Real),)
end

PlantSimEngine.environment_inputs_(::Beer) = (Ri_PAR_f=0.0,)

function PlantSimEngine.outputs_(::Beer)
    (aPPFD=-Inf,)
end


"""
    run!(object, environment, constants = Constants())

Computes the light interception of an object using the Beer-Lambert law.

# Arguments

- `::Beer`: a Beer light-interception model.
- `status`: object state with `lai` initialized in m² m⁻².
- `environment`: meteorology structure, see [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)
- `constants = PlantMeteo.Constants()`: physical constants. See `PlantMeteo.Constants` for more details

# Examples

```julia
using XPalm, PlantSimEngine, PlantMeteo
environment = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)
scene = CompositeModel(
    Object(:scene; scale=:Scene, kind=:scene, status=Status(lai=2.0));
    applications=(
        ModelSpec(Beer(0.5); on=One(scale=:Scene)),
    ),
    environment=environment,
)
run!(scene)
only(model_objects(scene; scale=:Scene)).status.aPPFD
```
"""
function PlantSimEngine.run!(m::Beer, status, environment, constants, context=nothing)
    status.aPPFD = # in mol[PAR] m[soil]⁻² d⁻¹
        environment.Ri_PAR_f * # in MJ m[soil]⁻² d⁻¹
        (1.0 - exp(-m.k * status.lai)) *
        constants.J_to_umol

    return nothing
end


"""
    SceneToPlantLightPartitioning()

Partitioning from aPPFD at the scene scale to the plant scale based on the relative 
leaf area of the plant.

# Arguments

- `scene_area`: the surface area of the scene (m⁻²) occupied by the plant.

# Inputs 

- `aPPFD`: absorbed Photosynthetic Photon Flux Density in mol[PAR] m[soil]⁻² d⁻¹ (scene scale).
- `leaf_area`: the target plant leaf area
- `scene_leaf_area`: the total scene leaf area

# Outputs

- `aPPFD`: absorbed Photosynthetic Photon Flux Density in mol[PAR] plant⁻¹ s⁻¹.
"""
struct SceneToPlantLightPartitioning{T} <: AbstractLight_InterceptionModel
    scene_area::T
end

function PlantSimEngine.inputs_(::SceneToPlantLightPartitioning)
    (
        aPPFD_scene=PlantSimEngine.Required(Real),
        leaf_area=PlantSimEngine.Required(Real),
        scene_leaf_area=PlantSimEngine.Required(Real),
    )
end

function PlantSimEngine.outputs_(::SceneToPlantLightPartitioning)
    (aPPFD=-Inf,)
end

# Partitioning between plants:
function PlantSimEngine.run!(m::SceneToPlantLightPartitioning, status, environment, constants, context=nothing)
    # aPPFD in mol[PAR] plant⁻¹ d⁻¹, from aPPFD in mol[PAR] m[scene]⁻² d⁻¹ and the plant's relative leaf area:
    status.aPPFD = status.aPPFD_scene * m.scene_area * status.leaf_area / status.scene_leaf_area
end
