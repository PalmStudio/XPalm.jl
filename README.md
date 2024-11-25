# XPalm - Growth and yield model for oil palm <img src="https://commons.wikimedia.org/wiki/File:Elaeis_guineensis_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-056.jpg#/media/Fichier:Elaeis_guineensis_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-056.jpg" alt="" width="300" align="right" />

<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/XPalm.jl/stable/) -->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/XPalm.jl/dev/)
[![Build Status](https://github.com/PalmStudio/XPalm.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/XPalm.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/XPalm.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/PalmStudio/XPalm.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

## Overview

[XPalm](https://github.com/PalmStudio/XPalm.jl) is a growth and yield model for oil palm (*Elaeis guineensis*).

## Installation

The package can be installed using the Julia package manager. From the Julia REPL, type `]` to enter the Pkg REPL mode and run:

```julia
pkg> add https://github.com/PalmStudio/XPalm.jl
```

To use the package, type the following in the Julia REPL:

```julia
using XPalm
```

## Running the model

### The easiest way of running the model

The easiest way to run the model is to use the template notebook provided by the package. To run the notebook, you need to install the Pluto package first by running `] add Pluto`. Then, you can run the notebook by running the following commands in the Julia REPL:

```julia
using Pluto, XPalm
Pluto.run(joinpath(dirname(pathof(XPalm)), "..", "notebooks", "XPalm.jl")
XPalm.notebook("xpalm_notebook.jl")
```

This command will create a new Pluto notebook (named "xpalm_notebook.jl") in the current directory, and open it automatically for you.

Once cosed, you can re-open this notebook by running the same command again. If the file already exists, it will be opened automatically.

### Programmatically running the model

The model can be run using the `xpalm` function. The function takes a table as input and returns a table with the same format as result. The `vars` argument is a dictionary that maps the names of the columns in the input table to the names of the variables in the model. The `sink` argument specifies the type of the output table such as a `DataFrame`, or any table implementing the `Tables.jl` interface (*e.g.* [XSLX](https://github.com/felipenoris/XLSX.jl), [SQLite](https://github.com/JuliaDatabases/SQLite.jl), [Arrow](https://github.com/apache/arrow-julia), see here [for all integrations](https://github.com/JuliaData/Tables.jl/blob/main/INTEGRATIONS.md)).

```julia
using XPalm, CSV, DataFrames
meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
df = xpalm(meteo, DataFrame; vars= Dict("Scene" => (:lai,)))
```

!!! note
    You need to install the `CSV` and `DataFrames` packages to run the example above. You can install them by running `] add CSV DataFrames`.

We can also run the model with a custom configuration file for the parameter values. The configuration file may be in any format that can be parsed into a dictionary, such as JSON, YAML or TOML.

For example, to run the model with a JSON configuration file:

```julia
using JSON # You first need to install the JSON package by running `] add JSON`
params = open("examples/xpalm_parameters.json", "r") do io
    JSON.parse(io; dicttype=Dict{Symbol,Any}, inttype=Int64)
end
p = XPalm.Palm(parameters=params)
df = xpalm(meteo, DataFrame; palm=p, vars=Dict("Scene" => (:lai,)))
```

Or with a YAML file:

```julia
using YAML # You first need to install the YAML package by running `] add YAML`
params = YAML.load_file(joinpath(dirname(dirname(pathof(XPalm))), "examples/xpalm_parameters.yml"), dicttype=Dict{Symbol,Any})
df = xpalm(meteo, DataFrame; palm=XPalm.Palm(parameters=params), vars=Dict("Scene" => (:lai,)))
```

!!! note
    The configuration file must contain all the parameters required by the model. Template files are available from the `examples` folder.

## Funding

This work is supported by the PalmStudio research project, funded by the [SMART Research Institute](https://smartri.id/) and [CIRAD](https://www.cirad.fr/en).

## To do

- [ ] Manage the case when photosynthesis + reserves are not enough for maintenance respiration: e.g. abortions?
- [ ] Add variable that tells us how far we are from the demand, i.e. (demand - allocation)
- [ ] Test difference between LeafCarbonDemandModelArea and LeafCarbonDemandModelPotentialArea. The first assumes that the leaf can always increase its demand more than the potential to catch back any delay in growth induced by previous stress. The second assumes that the potential daily increment only follows the daily potential curve, and that any lost demand induced by stress will be lost demand.
- [ ] There can still be some carbon offer at the end of the day, where do we put it?
- [ ] Increase the new internode size when the reserves are full?
- [ ] Check the carbon balance (add it as a variable?)
- [ ] In carbon allocation, put again `reserve` as needed input. We had to remove it because PSE detects a cyclic dependency with reserve filling. This is ok to remove because carbon allocation needs the value from the day before.
- [ ] calibration of 'final_potential_biomass' check on ECOPALM data the maximum number of furit and maximal individual fruit
- [ ] Add harvest management: remove fruits, remove leaves
- [ ] Compute the trophic status of the phytomer and females as a proper process (see number_fruits + sex_determination)
- [ ] Add litter (when leaves are removed) + male inflorescences
- [x] Add peduncle carbon demand and biomass for the female
- [x] Review how maintenance respiration is computed (add Male and Female)