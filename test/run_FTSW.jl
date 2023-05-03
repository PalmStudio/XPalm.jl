# Import dependencies
using PlantMeteo, PlantBiophysics, PlantSimEngine
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics

include("../src/soil/FTSW.jl")
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

m[:qty_H2O_Vap]

# export outputs
df = DataFrame(m)

CSV.write("2-outputs/out_runFTSW.csv", df)

