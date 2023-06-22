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
    stem = plant[2]
    roots = plant[1]
    leaf1 = get_node(p.mtg, 8)
    internode1 = get_node(p.mtg, 7)
    leaf2 = get_node(p.mtg, 11)
    female = get_node(scene, 171)
end

plant[:models].status.carbon_demand
lines(plant[:models].status.carbon_assimilation - plant[:models].status.carbon_demand)

plant_models = MultiScaleTreeGraph.ancestors(female, :models, symbol="Plant")[1]
plant_status_prev = plant_models.status[200-1]
plant_status_prev[:carbon_offer_after_rm]

female[:models].status.TT_since_init

male_demand = traverse(scene, symbol="Male") do node
    node[:models].status[:carbon_demand]
end

a = male_demand[1]
unique(a)



females_var = traverse(scene, symbol="Female") do node
                  node[:models].status[:carbon_offer_fruits]
              end |> first |> unique


plant[:models].status.carbon_offer_after_rm
plant[:models].status.carbon_demand
unique(females_var[1])

lines(plant[:models].status.carbon_assimilation - plant[:models].status.carbon_demand)

lines(plant[:models].status.carbon_demand)

male_demand = traverse(scene, symbol="Male") do node
    node[:models].status[:sex]
end

a = male_demand[1]
unique(a)

lines(plant[:models].status.carbon_demand)


lines(scene[:models].status.lai)
lines(scene[:models].status.aPPFD)
lines(plant[:models].status.aPPFD)
lines(plant[:models].status.leaf_area)
lines(plant[:models].status.biomass ./ 1000, axis=(ylabel="Total drymass (kg plant⁻¹)",))
lines(plant[:models].status.carbon_assimilation)
lines(plant[:models].status.carbon_offer_after_allocation)
lines(plant[:models].status.reserve)
lines(plant[:models].status.Rm)

lines(roots[:models].status.ftsw)
lines(soil[:models].status.ftsw)
lines(roots[:models].status.root_depth)
lines(soil[:models].status.root_depth)
lines(roots[:models].status.soil_depth)
lines(soil[:models].status.soil_depth)

lines(plant[:models].status.carbon_allocation_organs)

f, ax, plt = lines(soil[:models].status.SizeC, label="SizeC")
# lines!(ax, soil[:models].status.qty_H2O_C, label="qty_H2O_C")
# lines!(ax, soil[:models].status.qty_H2O_C1minusVap, label="qty_H2O_C1minusVap")
lines!(ax, soil[:models].status.qty_H2O_C2, label="qty_H2O_C2")
lines!(ax, soil[:models].status.qty_H2O_C, color="red")
lines!(ax, soil[:models].status.qty_H2O_C1minusVap, color="green")
f

transmitted_light_fraction = ((meteo.Ri_PAR_f * constants.J_to_umol) - st.aPPFD) / (meteo.Ri_PAR_f * constants.J_to_umol)
lines((meteo.Ri_PAR_f[1:100] .* Constants().J_to_umol .- soil[:models].status.aPPFD[1:100]) ./ (meteo.Ri_PAR_f[1:100] .* Constants().J_to_umol))
lines((meteo.Ri_PAR_f[1:100] .* Constants().J_to_umol .- soil[:models].status.aPPFD[1:100]))
lines(scene[:models].status.aPPFD[1:100])
lines(plant[:models].status.aPPFD[1:100])

lines(scene[:models].status.aPPFD[1:89])
lines(scene[:models].status.aPPFD[1:88])



plant[:models].status.carbon_assimilation[88]
plant[:models].status.leaf_area[88]

phytomer = get_node(p.mtg, 6)
unique(phytomer[:models].status.TT_since_init)
unique(phytomer[:models].status.sex)




lines(scene[:models].status.lai[1:100])
lines(soil[:models].status.ftsw[1:100])
lines(soil[:models].status.transpiration[1:100])

f, ax, plt = lines(soil[:models].status.aPPFD[1:200])
lines!(ax, meteo.Ri_PAR_f * Constants().J_to_umol, color="red")
f


transmitted_light_fraction = ((meteo.Ri_PAR_f * constants.J_to_umol) - st.aPPFD) / (meteo.Ri_PAR_f * constants.J_to_umol)



lines(soil[:models].status.ftsw)
lines(soil[:models].status.ET0)
lines(soil[:models].status.aPPFD)
lines(soil[:models].status.root_depth)


lines(plant[:models].status.carbon_assimilation)
lines(plant[:models].status.carbon_assimilation - plant[:models].status.carbon_allocation_organs)


lines(stem[:models].status.reserve)
lines(stem[:models].status.biomass)
lines(stem[:models].status.carbon_offer)
# lines(internode1[:models].status.TT_since_init)

plant[:models].status.carbon_assimilation
plant[:models].status.reserve
internode1[:models].status.carbon_demand
leaf1[:models].status.carbon_demand

internode1[:models].status.carbon_allocation
leaf1[:models].status.carbon_allocation

internode1[:models].status.biomass
leaf1[:models].status.biomass
leaf1[:models].status.leaf_area
scene[:models].status.lai
scene[:models].status.aPPFD

plant[:models].status.biomass

lines(internode1[:models].status.potential_height)
lines(internode1[:models].status.potential_radius)
lines(internode1[:models].status.carbon_allocation)
lines(internode1[:models].status.biomass)
lines(internode1[:models].status.height)
lines(internode1[:models].status.radius)
lines(plant[:models].status.carbon_allocation_organs)


timestep = 87

scene[:models].status.lai[timestep]
scene[:models].status.aPPFD[timestep]
plant[:models].status.aPPFD[timestep]
plant[:models].status.carbon_allocation[timestep]
n_phyto_timestep = plant[:models].status.phytomers[timestep]

out = MultiScaleTreeGraph.traverse(p.mtg, symbol="Leaf") do node
    node[:models].status.carbon_allocation[timestep]
end[1:Int(n_phyto_timestep)]
sum(out)
out = MultiScaleTreeGraph.traverse(p.mtg, symbol="Leaf") do node
    node[:models].status.carbon_demand[timestep]
end[1:Int(n_phyto_timestep)]
sum(out)
out = MultiScaleTreeGraph.traverse(p.mtg, symbol="Internode") do node
    node[:models].status.carbon_demand[timestep]
end[1:Int(n_phyto_timestep)]
sum(out)
out = MultiScaleTreeGraph.traverse(p.mtg, symbol="Internode") do node
    node[:models].status.carbon_allocation[timestep]
end[1:Int(n_phyto_timestep)]
sum(out)

plant[:models].status.carbon_assimilation[timestep]
plant[:models].status.Rm[timestep]
plant[:models].status.reserve[timestep]
soil[:models].status.ftsw[timestep]

out = MultiScaleTreeGraph.traverse(p.mtg, symbol="Internode") do node
    node[:models].status.carbon_allocation[timestep]
end[1:Int(n_phyto_timestep)]
sum(out)

out = MultiScaleTreeGraph.traverse(p.mtg, symbol="Leaf") do node
    node[:models].status.carbon_allocation[timestep]
end[1:Int(n_phyto_timestep)]
sum(out)

findfirst(
    x -> x === plant[:models].status.reserve[end],
    plant[:models].status.reserve
)

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