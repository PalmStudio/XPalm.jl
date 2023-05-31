using XPalm
using Test
using Dates
using MultiScaleTreeGraph, PlantMeteo, PlantSimEngine
using CSV, DataFrames, Statistics
using CairoMakie
# Import the meteo data once:

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/Exemple_meteo.csv"), DataFrame)
rename!(
    meteo,
    :TMin => :Tmin,
    :TMax => :Tmax,
    :HRMin => :Rh_min,
    :HRMax => :Rh_max,
    :Rainfall => :Precipitations,
    :WindSpeed => :Wind,
)

# prevent missing values
replace!(meteo.Wind, missing => mean(skipmissing(meteo.Wind)))
replace!(meteo.Rg, missing => mean(skipmissing(meteo.Rg)))
transform!(
    meteo,
    :Rg => (x -> x .* 0.48) => :Ri_PAR_f,
)

m = ModelList(
    DailyDegreeDays(),
    FTSW(ini_root_depth=300.0),
    status=(ET0=1.0, aPPFD=1.0, root_depth=fill(300.0, nrow(meteo)))
)



m1 = ModelList(
    DailyDegreeDaysFTSW(),
    FTSW(ini_root_depth=300.0),
    status=(ET0=1.0, aPPFD=1.0, root_depth=fill(300.0, nrow(meteo)))
)

run!(m, meteo, executor=SequentialEx())

run!(m1, meteo, executor=SequentialEx())

lines(m[:ftsw],)

lines(m[:TT_since_init])
