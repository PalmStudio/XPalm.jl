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
    :WindSpeed => :Wind,
)

# prevent missing values
replace!(meteo.Wind, missing => mean(skipmissing(meteo.Wind)))
replace!(meteo.Rg, missing => mean(skipmissing(meteo.Rg)))
transform!(
    meteo,
    :Rg => (x -> x .* 0.48) => :Ri_PAR_f,
)

dirtest = joinpath(dirname(dirname(pathof(XPalm))), "test/")

@testset "Age_modulation" begin
    include(joinpath(dirtest, "test-age_modulation_linear.jl"))
    include(joinpath(dirtest, "test-age_modulation_logistic.jl"))
end

@testset "Palm" begin
    include(joinpath(dirtest, "test-palm.jl"))
end

@testset "ET0" begin
    include(joinpath(dirtest, "test-et0.jl"))
end

@testset "Soil" begin
    include(joinpath(dirtest, "test-FTSW_BP.jl"))
    include(joinpath(dirtest, "test-FTSW.jl"))
end

@testset "Roots" begin
    include(joinpath(dirtest, "test-roots.jl"))
end

@testset "Test utils" begin
    include("test-age_modulation.jl")
end

@testset "Running a simulation" begin
    include("test-run.jl")
end
