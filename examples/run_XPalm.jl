
# ]activate examples

# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
using CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using Dates
using XPalm

# meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
meteo_raw = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/Meteo_Nigeria_PR.txt"), DataFrame)

meteo = select(
    meteo_raw,
    :ObservationDate => :date,
    :ObservationDate => (x -> Day(1)) => :duration,
    :TAverage => (x -> replace(x, missing => mean(skipmissing(x)))) => :T,
    :TMax => (x -> replace(x, missing => mean(skipmissing(x)))) => :Tmax,
    :TMin => (x -> replace(x, missing => mean(skipmissing(x)))) => :Tmin,
    :Rg => (x -> replace(x, missing => mean(skipmissing(x))) .* 0.48) => :Rg,
    :Rg => (x -> replace(x, missing => mean(skipmissing(x))) .* 0.48) => :Ri_PAR_f,
    :HRMin => (x -> replace(x, missing => mean(skipmissing(x)))) => :Rh_min,
    :HRMax => (x -> replace(x, missing => mean(skipmissing(x)))) => :Rh_max,
    :Rainfall => (x -> replace(x, missing => mean(skipmissing(x)))) => :Precipitations,
    :WindSpeed => (x -> replace(x, missing => mean(skipmissing(x)))) => :Wind,
)
meteo.Rh .= (meteo.Rh_max .- meteo.Rh_min) ./ 2 ./ 100

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