using XPalm
using Test
using Dates
using MultiScaleTreeGraph, PlantMeteo, PlantSimEngine
using CSV, DataFrames, Statistics

# Import the meteo data once:

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)

# rename!(
#     meteo,
#     :TMin => :Tmin,
#     :TMax => :Tmax,
#     :HRMin => :Rh_min,
#     :HRMax => :Rh_max,
#     :Rainfall => :Precipitations,
#     :WindSpeed => :Wind,
# )

# prevent missing values
# replace!(meteo.Wind, missing => mean(skipmissing(meteo.Wind)))
# replace!(meteo.Rg, missing => mean(skipmissing(meteo.Rg)))
# transform!(
#     meteo,
#     :Rg => (x -> x .* 0.48) => :Ri_PAR_f,
# )

dirtest = joinpath(dirname(dirname(pathof(XPalm))), "test/")

@testset "Age" begin
    include(joinpath(dirtest, "test-age.jl"))
end

@testset "Light" begin
    include(joinpath(dirtest, "test-beer.jl"))
end

@testset "Micrometeorology" begin
    include(joinpath(dirtest, "test-micrometeo.jl"))
end

# @testset "Carbon_allocation" begin
#     include(joinpath(dirtest, "test-carbon_allocation.jl"))
# end

@testset "Carbon_assimilation" begin
    include(joinpath(dirtest, "test-rue.jl"))
end

@testset "Carbon_offer" begin
    include(joinpath(dirtest, "test-carbon_offer.jl"))
end

@testset "Dimensions" begin
    include(joinpath(dirtest, "test-dimensions.jl"))
end

@testset "Leaf area" begin
    include(joinpath(dirtest, "test-leaf_area.jl"))
end

# @testset "Number - fruits" begin
#     include(joinpath(dirtest, "test-number_fruits.jl"))
# end

@testset "Biomass" begin
    include(joinpath(dirtest, "test-biomass.jl"))
end

@testset "Carbon_demand" begin
    include(joinpath(dirtest, "test-carbon_demand.jl"))
end


@testset "Soil" begin
    include(joinpath(dirtest, "test-FTSW.jl"))
end

@testset "Roots" begin
    include(joinpath(dirtest, "test-roots.jl"))
end

@testset "Palm" begin
    include(joinpath(dirtest, "test-palm.jl"))
end

@testset "Running a simulation" begin
    include("test-run.jl")
end

@testset "PlantSimEngine" begin
    include("test-PlantSimEngine.jl")
end

