```@meta
CurrentModule = XPalm
```

# XPalm - A growth and yield model for oil palm

```@raw html
<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/XPalm.jl/stable/) -->
```

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/XPalm.jl/dev/)
[![Build Status](https://github.com/PalmStudio/XPalm.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/XPalm.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/XPalm.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/PalmStudio/XPalm.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

[XPalm](https://github.com/PalmStudio/XPalm.jl) is a growth and yield model for oil palm (*Elaeis guineensis*).

```@contents
Pages = ["index.md"]
Depth = 5
```

## Overview

XPalm is a process-based model for simulating oil palm (*Elaeis guineensis*) growth and development. The model simulates key physiological processes including:

- Phenology and development
- Carbon assimilation and allocation
- Water balance
- Reproductive organ development
- Yield components

XPalm implements a multiscale approach, modeling processes at different organizational levels:

Scene: Environment and canopy-level processes
Plant: Whole palm processes
Phytomer: Individual growth unit processes
Organ: Leaf, internode and reproductive organ processes

The model uses a daily time step and requires standard meteorological inputs (temperature, radiation, rainfall...).

The model also includes a submodule `VPalm` to design palm tree mockups from a set of architectural parameters and allometric equations. It is designed to integrate smoothly with the physiological models from the package.

The model is implemented in the [Julia programming language](https://julialang.org/), which is a high-level, high-performance dynamic programming language for technical computing.

## Example outputs

Here are some example outputs from the model, showing the evolution of variables at different scales:

**Scene level:**

Leaf area index (LAI) at the scene level over time:

![scene level](assets/simulation_results_Scene.png)

**Plant level:**

Maintenance respiration (Rm), absorbed PPFD (aPPFD), biomass of bunches harvested, and leaf area at the plant level over time:
 
![plant level](assets/simulation_results_Plant.png)

**Leaf level:**

Leaf area at the level of the individual leaf over time:

![leaf level](assets/simulation_results_Leaf.png)

**Soil level:**

Fraction of transpirable soil water (FTSW) over time:

![soil level](assets/simulation_results_Soil.png)


## Installation

Install XPalm using Julia's package manager, typing `]` in the Julia REPL (*i.e.* the console) to enter the Pkg REPL mode and then typing:

```julia
pkg> add XPalm
```

To use the package, type the following in the Julia REPL:

```julia
using XPalm
```

## Quick Start

From the Julia REPL, load the package:

```julia
using XPalm
```

### The easiest way of running the model

The easiest way to run the model is to use the template notebook provided by the package. To run the notebook, you need to install the Pluto package first by running `] add Pluto`. Then, you can run the notebook using the following commands in the Julia REPL:

```julia
using Pluto, XPalm
XPalm.notebook("xpalm_notebook.jl")
```

This command will create a new Pluto notebook (named "xpalm_notebook.jl") in the current directory, and open it automatically for you.

Once closed, you can re-open this notebook by running the same command again. If the file already exists, it will be opened automatically.

### Programmatically running the model

#### Basic simulation

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
# Read the parameters from a YAML file (provided in the example folder of the package). Note that parameter keys should be imported as `Symbol`s
using YAML
parameters = YAML.load_file(joinpath(dirname(dirname(pathof(XPalm))), "examples/xpalm_parameters.yml"); dicttype=Dict{Symbol,Any})

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
    JSON.parse(io; dicttype=Dict{Symbol,Any}, inttype=Int64)
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

## VPalm

The package also includes a submodule `VPalm` that is an automaton that builds 3d mockups of palm plants from architectural parameters and allometric equations. It also integrates a biomechanical model to compute the leaf bending and torsion using the biomass of each leaf.

You can run `VPalm` simply by loading the submodule. Here is an example to load `VPalm` default parameters and build a palm tree with a multiscale architecture defined using the [Multiscale Tree Graph format (MTG)](https://github.com/VEZY/MultiScaleTreeGraph.jl).

```julia
using XPalm
using XPalm.VPalm

# Load example parameters
file = joinpath(dirname(dirname(pathof(XPalm))), "test", "references", "vpalm-parameter_file.yml")
parameters = read_parameters(file)

mtg = build_mockup(parameters)

viz(mtg, color = :green)
```

![palm plant](assets/palm_mockup.png)

!!! details "Code to reproduce this image"
    To reproduce the image above, you can use the following code snippet. It will create a mockup of a palm plant with colored segments based on their type.

    ```julia
    using XPalm
    using XPalm.VPalm
    file = joinpath(dirname(dirname(pathof(XPalm))), "test", "references", "vpalm-parameter_file.yml")
    parameters = read_parameters(file)
    mtg = build_mockup(parameters; merge_scale=:leaflet)
    traverse!(mtg) do node
        if symbol(node) == "Petiole"
            petiole_and_rachis_segments = descendants(node, symbol=["PetioleSegment", "RachisSegment"])
            colormap = cgrad([colorant"peachpuff4", colorant"blanchedalmond"], length(petiole_and_rachis_segments), scale=:log2)
            for (i, seg) in enumerate(petiole_and_rachis_segments)
                seg[:color_type] = colormap[i]
            end
        elseif symbol(node) == "Leaflet"
            node[:color_type] = :mediumseagreen
        elseif symbol(node) == "Leaf" # This will color the snags
            node[:color_type] = :peachpuff4
        end
    end
    f, ax, p = viz(mtg, color=:color_type)
    save("palm_mockup.png", f, size=(800, 600), px_per_unit=3)
    ```

!!! note 
    Note that the MTG is built with the following scales: `["Plant", "Stem", "Phytomer", "Internode", "Leaf", "Petiole", "PetioleSegment", "Rachis", "RachisSegment", "Leaflet", "LeafletSegment"]`.

## Funding

This work is supported by the PalmStudio research project, funded by the [SMART Research Institute](https://smartri.id/) and [CIRAD](https://www.cirad.fr/en).

## API

### Index

```@index
```

### XPalm

Documentation for the main functions of the XPalm package.

```@autodocs
Modules = [XPalm]
```

### Models

Documentation for the models available in XPalm.

```@autodocs
Modules = [XPalm.Models]
```


### VPalm

Documentation for the main functions of the XPalm package.

```@autodocs
Modules = [XPalm.VPalm]
```
