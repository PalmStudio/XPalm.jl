# Programmatically running the model

Run a simple simulation using default parameters and meteorological data:

```julia
using XPalm, CSV, DataFrames

# Load example meteorological data
meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)

# Run simulation
df = xpalm(meteo, DataFrame;
    vars = Dict(:Scene => (:lai,)), # Request LAI as output
)
```

!!! note
    You need to install the `CSV` and `DataFrames` packages to run the example above. You can install them by running `] add CSV DataFrames`.

#### Advanced Usage

Customize palm parameters and request multiple outputs:

```julia
# Read the parameters from a YAML file (provided in the example folder of the package).
using YAML
parameters = YAML.load_file(joinpath(dirname(dirname(pathof(XPalm))), "examples/xpalm_parameters.yml"))

# Load example meteorological data
meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)

# Create palm with custom parameters
p = XPalm.Palm(parameters=parameters)

# Run simulation with multiple outputs
results = xpalm(
    meteo,
    DataFrame,
    vars = Dict(
        :Scene => (:lai,),
        :Plant => (:leaf_area, :biomass_bunch_harvested),
        :Soil => (:ftsw,)
    ),
    palm = p,
)
```

You can also import the parameters from a JSON file using the `JSON` package:

```julia
using JSON # You first need to install the JSON package by running `] add JSON`
params = open(joinpath(dirname(dirname(pathof(XPalm))), "examples/xpalm_parameters.json"), "r") do io
    JSON.parse(io; dicttype=Dict{String,Any}, inttype=Int64)
end
```

!!! note
    The configuration file must contain all the parameters required by the model. Template files are available from the `examples` folder.

## Meteorological input contracts

Models that read meteorological forcing declare those fields separately from
their status inputs. PlantSimEngine checks the declarations before numerical
execution and reports missing fields with the affected model application.

| Model | Environment fields |
|---|---|
| `ET0_BP` | `Tmin`, `Tmax`, `Rh_min`, `Rh_max`, `Rg`, `Wind`, `date` |
| `DailyDegreeDays`, `DegreeDaysFTSW`, `RmQ10FixedN` | `Tmin`, `Tmax` |
| `Beer` | `Ri_PAR_f` |
| `FTSW`, `FTSW_BP` | `Precipitations`, `Ri_PAR_f` |

These are the existing names read by the kernels. A scenario can remap source
names with `PlantSimEngine.Environment`. The declarations check field presence;
the numerical formulas and their unit assumptions are unchanged.

## Daily light quantity chain

XPalm's bundled meteorological file contains daily PAR energy, not an
instantaneous irradiance. The light and carbon chain keeps the public name
`aPPFD` at Scene, Soil, and Plant scales; the selected object and the
`VariableContract` state which quantity is being connected.

| Stage | Quantity | Contract |
|---|---|---|
| Meteorological input | `Ri_PAR_f` | MJ PAR m[ground]⁻² d⁻¹ |
| `Beer` on `Scene` | `aPPFD` | mol photon m[ground]⁻² d⁻¹, daily total per ground area |
| `FTSW` / `FTSW_BP` on `Soil` | `aPPFD` | the same daily total per ground area |
| `SceneToPlantLightPartitioning` on `Plant` | `aPPFD` | mol photon plant⁻¹ d⁻¹, daily total per plant |
| `ConstantRUEModel` / `RUE_FTSW` on `Plant` | `aPPFD` | the same daily total per plant |
| RUE output | `carbon_assimilation` | g C plant⁻¹ d⁻¹ |

The numerical conversion is

```math
aPPFD_{scene} = Ri_{PAR} \times \left(1 - \exp(-k\,LAI)\right) \times 4.57.
```

The same factor 4.57 converts MJ to mol here as converts J to μmol for an
instantaneous flux: the factors of one million cancel. The partition model then
computes

```math
aPPFD_{plant} = aPPFD_{scene} \times A_{scene} \times
\frac{A_{leaf,plant}}{A_{leaf,scene}}.
```

For XPalm's representative one-palm scene,
`A_scene = 10000 / planting_density` in m². For several plants, the leaf-area
fractions sum to one, so the sum of plant totals equals
`aPPFD_scene * A_scene`. The RUE models divide the plant total by 4.57 to recover
MJ PAR plant⁻¹ d⁻¹ before applying RUE. The soil-water models deliberately use
the Scene value instead, because their light interception fraction compares two
ground-area daily totals.

Subdaily `PlantMeteo.Atmosphere` forcing uses W m⁻² for radiation.
`PlantMeteo.to_daily` integrates those values with the step duration into
MJ m⁻² for each daily step; XPalm's maintained CSV is already in that daily
form. This forcing conversion is an input-boundary responsibility and is not
inferred from the numeric value.

`aPPFD_scene` remains only as the local input port of the partition model,
because the ground-area input and plant-total output coexist there. It does not
introduce a second public variable naming scheme.

#### Importing the models

The models are available from the `Models` submodule. To import all models, you can use the following command:

```julia
using XPalm
using XPalm.Models
```

#### More examples

The package provides an example script in the `examples` folder. To run it, you first have to place your working directory inside the folder, and then activate its environement by running `] activate .`.

You can also find example applications in the [Xpalm applications Github repository](https://github.com/PalmStudio/XPalm_applications).
