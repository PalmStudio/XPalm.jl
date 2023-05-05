# Import dependencies
using PlantMeteo, PlantSimEngine, Revise
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
# using CairoMakie

includet("../src/soil/FTSW.jl")
includet("../src/ThermalTime.jl")
includet("../src/root_growth.jl")

meteo = CSV.read("0-data/Exemple_meteo.csv", DataFrame)


soil = FTSW()
init = soil_init_default(soil)
init.ET0 = 1.0
init.tree_ei = 0.8
init.root_depth = 500.0
PlantSimEngine.dep(::FTSW) = (root_growth=AbstractRoot_GrowthModel,)

# meteo = first(meteo, 20)
m = ModelList(
    ThermalTime(),
    RootGrowth(),
    FTSW(),
    status=TimeStepTable{Status}([init for i in eachrow(meteo)])
    # status=TimeStepTable{Status}([init for i in eachrow(meteo)])
)

run!(m, meteo)
# lines(m[:ftsw])

# export outputs
df = DataFrame(m)
CSV.write("2-outputs/out_runFTSW.csv", df)