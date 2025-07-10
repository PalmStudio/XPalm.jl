# Programmatically running the model

Run a simple simulation using default parameters and meteorological data:

```julia
using XPalm, CSV, DataFrames

# Load example meteorological data
meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)

# Run simulation
df = xpalm(meteo, DataFrame;
    vars = Dict("Scene" => (:lai,)), # Request LAI as output
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
        "Scene" => (:lai,),
        "Plant" => (:leaf_area, :biomass_bunch_harvested),
        "Soil" => (:ftsw,)
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

#### Importing the models

The models are available from the `Models` submodule. To import all models, you can use the following command:

```julia
using XPalm
using XPalm.Models
```

#### More examples

The package provides an example script in the `examples` folder. To run it, you first have to place your working directory inside the folder, and then activate its environement by running `] activate .`.

You can also find example applications in the [Xpalm applications Github repository](https://github.com/PalmStudio/XPalm_applications).