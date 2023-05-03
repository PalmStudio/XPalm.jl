# Import dependencies
using PlantMeteo, PlantSimEngine, Revise
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics

includet("../src/soil/FTSW.jl")
meteo = CSV.read("0-data/Exemple_meteo.csv", DataFrame)

soil = FTSW()
init = soil_init_default(soil, 100.0)
init.ET0 = 1.0
init.tree_ei = 0.8

m = ModelList(
    FTSW(),
    status=TimeStepTable{Status}([init for i in eachrow(meteo)])
)

run!(m, meteo)

m[:ftsw]
m[:qty_H2O_C1]
m[:qty_H2O_C]
m[:SizeC]
status.qty_H2O_C / status.SizeC

using CairoMakie

lines(m[:qty_H2O_C])

# Which time step is the first one where qty_H2O_C < 0.0?
findfirst(x -> x < 0.0, m[:qty_H2O_C])

# Get the status of the model at that time step:
status(m)[684]

# Print all the values of the status at that time step:
PlantMeteo.row_struct(status(m)[684])
m[:qty_H2O_C][684]

st = PlantMeteo.row_struct(status(m)[684])

# export outputs
df = DataFrame(m)

CSV.write("2-outputs/out_runFTSW.csv", df)

