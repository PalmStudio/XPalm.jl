using XPalm
using Test
using Dates
using MultiScaleTreeGraph, PlantMeteo, PlantSimEngine
using CSV, DataFrames, Statistics

# Import the meteo data once:

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/Exemple_meteo.csv"), DataFrame)
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

@testset "Palm" begin
    include("test-palm.jl")
end

@testset "ET0" begin
    include("test-et0.jl")
end

@testset "Soil" begin
    include("test-FTSW.jl")
end

@testset "Roots" begin
    include("test-roots.jl")
end

@testset "Test utils" begin
    include("test-age_modulation.jl")
end

@testset "Running a simulation" begin
    include("test-run.jl")
end
