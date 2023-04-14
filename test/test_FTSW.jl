# Import dependencies

using PlantSimEngine, PlantMeteo, PlantBiophysics
using PlantGeom, CairoMakie
using DataFrames, CSV, AlgebraOfGraphics, Statistics

include("../src/soil/FTSW.jl")
