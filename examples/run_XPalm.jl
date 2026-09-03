
# ]activate examples

# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
using CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using Dates
using XPalm

meteo = CSV.read("0-data/meteo.csv", DataFrame)
meteo.duration .= Dates.Day(1)
m = Weather(meteo);

out_vars = Dict{Symbol,Any}(
    :Scene => (:lai, :leaf_area, :aPPFD),
    :Plant => (
        :plant_age, :ftsw, :newPhytomerEmergence, :aPPFD, :leaf_area, :carbon_assimilation,
        :carbon_offer_after_rm, :Rm, :TT_since_init, :TEff, :phytomer_count, :newPhytomerEmergence,
        :biomass_bunch_harvested
    ),
    :Leaf => (:Rm, :potential_area, :TT_since_init, :TEff, :A, :carbon_demand, :carbon_allocation, :leaf_area, :biomass),
    :Internode => (:Rm, :carbon_allocation, :carbon_demand, :biomass),
    :Male => (:Rm, :biomass),
    :Female => (:Rm, :biomass,),
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
df_Internode = df[:Internode]
df_scene = df[:Scene]
df_plant = df[:Plant]
df_soil = df[:Soil]
df_leaf = df[:Leaf]
df_male = df[:Male]
df_female = df[:Female]

# Add the date from the meteo into the dataframes (being careful as we have some new rows in the plant and leaf dataframes due to phytomer emergence, so using the timestep instead of the row index):
df_scene.date = meteo.date
df_plant.date = [meteo.date[t] for t in df_plant.timestep]
df_soil.date = meteo.date
df_leaf.date = [meteo.date[t] for t in df_leaf.timestep]
df_male.date = [meteo.date[t] for t in df_male.timestep]
df_female.date = [meteo.date[t] for t in df_female.timestep]
df_Internode.date = [meteo.date[t] for t in df_Internode.timestep]

data(df_scene) * mapping(:date, :lai) * visual(Lines) |> draw
data(df_plant) * mapping(:date, :Rm) * visual(Lines) |> draw
data(df_plant) * mapping(:date, :aPPFD) * visual(Lines) |> draw
data(meteo) * mapping(:date, :Ri_PAR_f) * visual(Lines) |> draw
data(df_scene) * mapping(:date, :aPPFD => (x -> x ./ 4.57)) * visual(Lines) |> draw
data(df_plant) * mapping(:date, :biomass_bunch_harvested) * visual(Lines) |> draw
data(df_plant) * mapping(:date, :leaf_area) * visual(Lines) |> draw
data(df_leaf) * mapping(:date, :leaf_area, color=:node => nonnumeric) * visual(Lines) |> draw
data(df_soil) * mapping(:date, :ftsw) * visual(Lines) |> draw



data(df_leaf) * mapping(:date, :Rm, color=:node => nonnumeric) * visual(Lines) |> draw
data(df_male) * mapping(:date, :Rm, color=:node => nonnumeric) * visual(Lines) |> draw
data(df_female) * mapping(:date, :Rm, color=:node => nonnumeric) * visual(Lines) |> draw
data(df_Internode) * mapping(:date, :Rm, color=:node => nonnumeric) * visual(Lines) |> draw


data(df_Internode) * mapping(:date, :Rm, color=:node => nonnumeric) * visual(Lines) |> draw

df_male.Rm[isinf.(df_male.Rm)]
df_male[findall(isinf, df_male.Rm), :]


df_male[findall(x -> x == 622, df_male.node), :]
df_female[findall(x -> x == 609, df_female.node), :]