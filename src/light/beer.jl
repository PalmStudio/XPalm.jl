"""
    Beer(k)

Beer-Lambert law for light interception.

# Arguments

- `k`: extinction coefficient of light

# Inputs 

- `lai` in m² m⁻².

# Environment inputs

- `Ri_PAR_f`: incident daily PAR energy, in MJ m[ground]⁻² d⁻¹.

# Outputs

- `aPPFD`: absorbed daily PAR in mol[photon] m[ground]⁻² d⁻¹.
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

PlantSimEngine.variable_contracts_(::Beer) = (
    aPPFD=_GROUND_DAILY_PAR_PHOTONS,
)


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
using XPalm, PlantSimEngine, PlantMeteo, Dates
environment = (
    Ri_PAR_f=8.0, # daily PAR energy in MJ m[ground]^-2 d^-1
    duration=Day(1),
)
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
    status.aPPFD = # in mol[photon] m[ground]⁻² d⁻¹
        environment.Ri_PAR_f * # in MJ m[ground]⁻² d⁻¹
        (1.0 - exp(-m.k * status.lai)) *
        constants.J_to_umol

    return nothing
end


"""
    SceneToPlantLightPartitioning(scene_area)

Partitioning from aPPFD at the scene scale to the plant scale based on the relative 
leaf area of the plant.

# Arguments

- `scene_area`: represented ground area of the scene (m²). In XPalm's default
  one-palm scene this is `10000 / planting_density` for a density in palm ha⁻¹.

# Inputs 

- `aPPFD_scene`: absorbed PAR in mol[photon] m[ground]⁻² d⁻¹.
- `leaf_area`: the target plant leaf area in m².
- `scene_leaf_area`: the total scene leaf area in m².

# Outputs

- `aPPFD`: absorbed PAR in mol[photon] plant⁻¹ d⁻¹.

The local input name `aPPFD_scene` distinguishes the ground-area value from the
plant-total `aPPFD` output because both coexist inside this conversion model.
The ordinary published variable remains `aPPFD` at both object scales.
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

PlantSimEngine.variable_contracts_(::SceneToPlantLightPartitioning) = (
    aPPFD_scene=_GROUND_DAILY_PAR_PHOTONS,
    aPPFD=_PLANT_DAILY_PAR_PHOTONS,
)

# Partitioning between plants:
function PlantSimEngine.run!(m::SceneToPlantLightPartitioning, status, environment, constants, context=nothing)
    # aPPFD in mol[PAR] plant⁻¹ d⁻¹, from aPPFD in mol[PAR] m[scene]⁻² d⁻¹ and the plant's relative leaf area:
    status.aPPFD = status.aPPFD_scene * m.scene_area * status.leaf_area / status.scene_leaf_area
end
