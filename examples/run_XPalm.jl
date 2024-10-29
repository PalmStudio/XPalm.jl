
# ]activate examples

# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
using CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using Dates
using XPalm

meteo = CSV.read("0-data/Meteo_Nigeria_PR.txt", DataFrame)
meteo.duration = [Dates.Day(i[1:1]) for i in meteo.duration]
m = Weather(meteo)

out_vars = Dict{String,Any}(
    "Scene" => (:lai, :scene_leaf_area, :aPPFD, :TEff),
    "Plant" => (:plant_age, :ftsw, :newPhytomerEmergence, :aPPFD, :plant_leaf_area, :carbon_assimilation, :carbon_offer_after_rm, :Rm, :TT_since_init, :TEff, :phytomer_count, :newPhytomerEmergence),
    "Leaf" => (:Rm, :potential_area, :TT_since_init, :TEff),
    "Internode" => (:Rm, :potential_height, :carbon_demand),
    # "Male" => (:Rm,),
    # "Female" => (:Rm,),
    # "Leaf" => (:A, :carbon_demand, :carbon_allocation, :TT),
    # "Internode" => (:carbon_allocation,),
    "Soil" => (:TEff, :ftsw, :root_depth),
)

df = xpalm(m; vars=out_vars, sink=DataFrame)
df_Internode = filter(row -> row.organ == "Internode", df)
df_scene = filter(row -> row.organ == "Scene", df)
df_plant = filter(row -> row.organ == "Plant", df)
df_soil = filter(row -> row.organ == "Soil", df)
df_leaf = filter(row -> row.organ == "Leaf", df)

lines(df_plant.phytomer_count)
lines(df_scene.scene_leaf_area)
lines(df_scene.lai)
lines(df_scene.scene_leaf_area)
lines(df_scene.TEff)
lines(df_plant.carbon_assimilation)