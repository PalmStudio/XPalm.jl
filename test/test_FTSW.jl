# Import dependencies

using PlantSimEngine, PlantMeteo, PlantBiophysics
using PlantGeom, CairoMakie
using DataFrames, CSV, AlgebraOfGraphics, Statistics

include("../src/soil/FTSW.jl")

# meteo = Atmosphere(T=22.0, Wind=0.8333, P=101.325, Rh=0.4490995)

meteo = CSV.read("0-data/Exemple_meteo.csv", DataFrame)

soil = ModelList(FTSW(),
    status=())

run!(soil, meteo)


