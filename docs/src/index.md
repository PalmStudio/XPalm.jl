```@meta
CurrentModule = XPalm
```

# XPalm - Growth and yield model for oil palm

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

The model can be run using the `xpalm` function. The function takes a table as input and returns a table with the same format as result. The `vars` argument is a dictionary that maps the names of the columns in the input table to the names of the variables in the model. The `sink` argument specifies the type of the output table such as a `DataFrame`, or any table implementing the `Tables.jl` interface (*e.g.* [XSLX](https://github.com/felipenoris/XLSX.jl), [SQLite](https://github.com/JuliaDatabases/SQLite.jl), [Arrow](https://github.com/apache/arrow-julia), see here [for all integrations](https://github.com/JuliaData/Tables.jl/blob/main/INTEGRATIONS.md)).

```julia
using XPalm, CSV, DataFrames
meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
df = xpalm(meteo; vars= Dict("Scene" => (:lai,)), sink=DataFrame)
```

## Funding

This work is supported by the PalmStudio research project, funded by the [SMART Research Institute](https://smartri.id/) and [CIRAD](https://www.cirad.fr/en).

## API

```@index
```

```@autodocs
Modules = [XPalm]
```