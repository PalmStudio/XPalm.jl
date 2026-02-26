
# ]activate examples

# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
using CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using Dates
using XPalm

meteo = CSV.read("0-data/meteo", DataFrame)
meteo.duration = [Dates.Day(i[1:1]) for i in meteo.duration]
m = Weather(meteo)

out_vars = Dict{Symbol,Any}(
    :Scene => (:lai, :leaf_area, :aPPFD),
    :Plant => (:plant_age, :ftsw, :newPhytomerEmergence, :aPPFD, :leaf_area, :carbon_assimilation, :carbon_offer_after_rm, :Rm, :TT_since_init, :TEff, :phytomer_count, :newPhytomerEmergence),
    :Leaf => (:Rm, :potential_area, :TT_since_init, :TEff, :A, :carbon_demand, :carbon_allocation,),
    :Internode => (:Rm, :carbon_allocation, :carbon_demand),
    :Male => (:Rm,),
    :Female => (:biomass,),
    :Soil => (:TEff, :ftsw, :root_depth),
)

# Example 1: Run the model with the default parameters (but output as a DataFrame):
df = xpalm(m, DataFrame; vars=out_vars)

# Example 2.1: Run the model with custom parameter values from a YAML file:
using YAML, OrderedCollections
params = YAML.load_file(joinpath(dirname(dirname(pathof(XPalm))), "examples/xpalm_parameters.yml"))
params["k"] = 0.6
p = XPalm.Palm(parameters=params)
df = xpalm(m, DataFrame; palm=p, vars=out_vars)

# Example 2.2: Run the model with custom parameter values from a JSON file:
using JSON, OrderedCollections
params = open("examples/xpalm_parameters.json", "r") do io
    JSON.parse(io; dicttype=OrderedDict{String,Any}, inttype=Int64)
end
params["k"] = 0.6
p = XPalm.Palm(parameters=params)
df = xpalm(m, DataFrame; palm=p, vars=out_vars)

# Making some plots with the results:
df_Internode = filter(row -> row.organ == :Internode, df)
df_scene = filter(row -> row.organ == :Scene, df)
df_plant = filter(row -> row.organ == :Plant, df)
df_soil = filter(row -> row.organ == :Soil, df)
df_leaf = filter(row -> row.organ == :Leaf, df)

lines(df_scene.lai)
lines(df_plant.phytomer_count)
lines(df_scene.leaf_area)
lines(df_scene.leaf_area)
lines(df_plant.leaf_area)
lines(df_plant.carbon_assimilation)

data(df_leaf) * mapping(:timestep, :carbon_demand, color=:node => nonnumeric) * visual(Lines) |> draw