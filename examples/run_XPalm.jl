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

m = FTSW(3.0, 0.23, 0.05, 200.0,
    0.1,
    2000.0,
    0.15,
    1.0,
    0.5,
    0.5, 0.0, 0.0, 0.0, 0.0, 0.0)


# meteo = first(meteo, 20)
init_root_depth = 3.0
m = ModelList(
    ET0_BP(),
    DailyDegreeDays(),
    RootGrowthFTSW(init_root_depth),
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


ini_root_depth = 300.0
m = ModelList(
    # ET0_BP(),
    # DailyDegreeDays(),
    RootGrowthFTSW(ini_root_depth=ini_root_depth),
    FTSW(ini_root_depth=ini_root_depth),
    status=TimeStepTable{PlantSimEngine.Status}([init for i in eachrow(meteo)])
    # status=TimeStepTable{Status}([init for i in eachrow(meteo)])
)


m = ModelList(
    # ET0_BP(),
    # DailyDegreeDays(),
    # RootGrowthFTSW(),
    FTSW(),
    # status=(root_depth=fill(1.0, 916), tree_ei=0.8)
    # status=TimeStepTable{Status}([init for i in eachrow(meteo)])
)
to_initialize(m)


run!(m, meteo)
m[:ftsw]