# Import dependencies
using PlantMeteo, PlantSimEngine, Revise
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using GLMakie
using XPalm

meteo = CSV.read("0-data/Exemple_meteo.csv", DataFrame)

rename!(meteo,
    :TMin => :Tmin,
    :TMax => :Tmax,
    :Rainfall => :Precipitations)
begin
    soil = FTSW()
    init = soil_init_default(soil)
    init.ET0 = 1.0
    init.tree_ei = 0.8
    init.root_depth = 91.0


    # meteo = first(meteo, 20)
    m = ModelList(
        ThermalTime(),
        RootGrowth(),
        FTSW(),
        status=TimeStepTable{PlantSimEngine.Status}([init for i in eachrow(meteo)])
        # status=TimeStepTable{Status}([init for i in eachrow(meteo)])
    )

    run!(m, meteo)
    lines(m[:ftsw])
end
lines(m[:TEff])
lines(m[:root_depth])

# export outputs
df = DataFrame(m)
CSV.write("2-outputs/out_runFTSW.csv", df)