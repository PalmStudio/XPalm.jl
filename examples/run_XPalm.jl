# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using GLMakie
using XPalm
using DataFramesMeta

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

p = Palm(nsteps=nrow(meteo))

scene = p.mtg
soil = scene[1]
plant = scene[2]
roots = plant[1]
XPalm.run_XPalm(p, meteo)

scatter(filter(x -> x > -9999, get_node(p.mtg, 18)[:models].status.rank))

get_node(p.mtg, 9)[:models].status.rank

lines(plant[:models].status.leaf_area)

lines(plant[:models].status.ftsw)



leaf_95 = get_node(p.mtg, 95)
leaf_101 = get_node(p.mtg, 101)
f, ax, plt = lines(filter(x -> x > -Inf, leaf_101[:models].status[:leaf_area]), color="blue")

ax2 = Axis(f[1, 2])
lines!(ax2, filter(x -> x > -Inf, leaf_95[:models].status[:leaf_area]), color="red")
f

get_node(p.mtg, 8)[:models].models.leaf_rank

leaf_area = MultiScaleTreeGraph.traverse(p.mtg, symbol="Leaf") do node
    node[:models].status[200][:leaf_area]
end

get_node(p.mtg, 8)[:models].status[200][:leaf_area]
unique(get_node(p.mtg, 8)[:models].status[:final_potential_area])

sum(filter(x -> x > 0.0, leaf_area))
1

# soil = FTSW(ini_root_depth=500)
# init = soil_init_default(soil)
# init.ET0 = 1.0
# init.tree_ei = 0.8
# init.root_depth = 500.0

# m = FTSW(3.0, 0.23, 0.05, 200.0,
#     0.1,
#     2000.0,
#     0.15,
#     1.0,
#     0.5,
#     0.5, 0.0, 0.0, 0.0, 0.0, 0.0)


# meteo = first(meteo, 20)
# init_root_depth = 3.0
# m = ModelList(
#     ET0_BP(),
#     DailyDegreeDays(),
#     # RootGrowthFTSW(init_root_depth),
#     FTSW(ini_root_depth=init_root_depth,),
#     status=TimeStepTable{PlantSimEngine.Status}([init for i in eachrow(meteo)])
#     # status=TimeStepTable{Status}([init for i in eachrow(meteo)])
# )

# run!(m, meteo)
# lines(m[:ET0])
# lines!(m[:ftsw], col=2)

# lines(meteo.Rh_min, col=1)
# lines!(meteo.Rh_max, col=2)
# lines(m[:root_depth])

# # export outputs
# df = DataFrame(m)
# CSV.write("2-outputs/out_runFTSW.csv", df)


# ini_root_depth = 700.0

# m = ModelList(
#     ET0_BP(),
#     DailyDegreeDays(),
#     RootGrowthFTSW(ini_root_depth=init_root_depth),
#     XPalm.FTSW _BP(ini_root_depth=init_root_depth),
#     status=(root_depth=fill(1.0, 916), tree_ei=0.8)
#     # status=TimeStepTable{Status}([init for i in eachrow(meteo)])
# )
# to_initialize(m)


# run!(m, meteo)
# lines(m[:ftsw])