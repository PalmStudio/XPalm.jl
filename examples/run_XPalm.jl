# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using CairoMakie
using XPalm

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

XPalm.run_XPalm(p, meteo)

begin
    scene = p.mtg
    soil = scene[1]
    plant = scene[2]
    roots = plant[1]
    leaf1 = get_node(p.mtg, 8)
    leaf2 = get_node(p.mtg, 11)
end


lines(scene[:models].status.lai)
lines(plant[:models].status.leaf_area)
lines(plant[:models].status.carbon_demand)
lines(plant[:models].status.carbon_assimilation - plant[:models].status.carbon_demand)
lines(plant[:models].status.carbon_allocation_reserve_leaves)

lines(plant[:models].status.total_reserve_potential_leaves)
lines(plant[:models].status.carbon_offer)
lines(plant[:models].status.carbon_demand)

lines(plant[:models].status.carbon_allocation_leaves)
lines(plant[:models].status.ftsw)
lines(roots[:models].status.root_depth)

timestep = 6

plant[:models].status.phytomers[timestep]
plant[:models].status.phytomers[1:11]

leaf1[:models].status.reserve
leaf_reserve_potential = MultiScaleTreeGraph.traverse(plant, symbol="Leaf") do leaf
    st_leaf = leaf[:models].status[timestep]
    leaf_reserve_max = (200 - 80) * st_leaf.leaf_area / 0.35
    res_prev = PlantMeteo.prev_value(st_leaf, :reserve, default=0.0)
    # if res_prev == -Inf
    #     res_prev = st_leaf.reserve
    # end
    # leaf_reserve_max - res_prev
end

leaf_reserve_potential[1]



lines(leaf1[:models].status.biomass)
lines(leaf1[:models].status.leaf_area)
lines(leaf1[:models].status.carbon_allocation)

lines(filter(x -> x > -Inf, leaf2[:models].status.biomass))
lines(leaf2[:models].status.leaf_area)
lines(leaf2[:models].status.carbon_allocation)

leaf_area = MultiScaleTreeGraph.traverse(plant, symbol="Leaf") do leaf
    leaf[:models].status[1][:leaf_area]
end



plant[:models].status.carbon_demand[1]






scatter(filter(x -> x > -9999, get_node(p.mtg, 18)[:models].status.rank))

get_node(p.mtg, 9)[:models].status.rank


leaf_95 = get_node(p.mtg, 95)
leaf_101 = get_node(p.mtg, 101)


lines(filter(x -> x > -Inf, leaf_101[:models].status.carbon_allocation))


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