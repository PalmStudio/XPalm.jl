# Import dependencies
using PlantMeteo, PlantSimEngine, Revise
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using GLMakie
using XPalm
using DataFramesMeta

meteo = CSV.read("0-data/Exemple_meteo.csv", DataFrame)

rename!(
    meteo,
    :TMin => :Tmin,
    :TMax => :Tmax,
    :HRMin => :Rh_min,
    :HRMax => :Rh_max,
    :Rainfall => :Precipitations,
    :WindSpeed => :Wind
)

# prevent missing values
replace!(meteo.Wind, missing => mean(skipmissing(meteo.Wind)))
replace!(meteo.Rg, missing => mean(skipmissing(meteo.Rg)))


soil = FTSW()
init = soil_init_default(soil)
init.ET0 = 1.0
init.tree_ei = 0.8
init.root_depth = 500.0

# meteo = first(meteo, 20)
m = ModelList(
    ET0_BP(),
    DailyDegreeDays(),
    RootGrowth(),
    FTSW(),
    status=TimeStepTable{PlantSimEngine.Status}([init for i in eachrow(meteo)])
    # status=TimeStepTable{Status}([init for i in eachrow(meteo)])
)

run!(m, meteo)
lines(m[:ET0])
lines!(m[:ftsw], col=2)

lines(meteo.Rh_min, col=1)
lines!(meteo.Rh_max, col=2)
lines(m[:root_depth])

# export outputs
df = DataFrame(m)
CSV.write("2-outputs/out_runFTSW.csv", df)