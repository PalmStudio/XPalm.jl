using XPalm
using XPalm.Models
using XPalm.VPalm
import XPalm: Palm
using Aqua
using JET
using GeometryBasics
using CairoMakie
using ReferenceTests
using Test
using Dates
using Random
import StableRNGs: StableRNG
using MultiScaleTreeGraph, PlantGeom, PlantMeteo, PlantSimEngine
using CSV, DataFrames, Statistics, Unitful
# Import the meteo data once:

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
if :duration ∉ names(meteo)
    meteo.duration = fill(Day(1), nrow(meteo))
end

dirtest = joinpath(dirname(dirname(pathof(XPalm))), "test/")

# VPalm parameters
vpalm_parameters = read_parameters(joinpath(dirtest, "references", "vpalm-parameter_file.yml"))
vpalm_parameters2 = read_parameters(joinpath(dirtest, "references", "vpalm-parameter_file-missing_rachis_final_lengths.yml"))

@testset "Code quality (Aqua.jl)" begin
    Aqua.test_all(XPalm, ambiguities=false)
end

if VERSION >= v"1.10"
    # See this issue: https://github.com/aviatesk/JET.jl/issues/665
    @testset "Code linting (JET.jl)" begin
        JET.test_package(XPalm; target_modules=(XPalm, XPalm.Models, XPalm.VPalm))
    end
end

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

@testset "VPalm" begin

    @testset "Parameters IO" begin
        include(joinpath(dirtest, "test-vpalm-parameters_IO.jl"))
    end

    @testset "Units" begin
        include(joinpath(dirtest, "test-vpalm-check_units.jl"))
    end

    @testset "Stem allometries" begin
        include(joinpath(dirtest, "test-vpalm-stem.jl"))
    end

    @testset "Petiole" begin
        include(joinpath(dirtest, "test-vpalm-petiole.jl"))
    end

    @testset "Geometry" begin
        include(joinpath(dirtest, "test-vpalm-geometry.jl"))
    end

    @testset "Biomechanical model" begin
        include(joinpath(dirtest, "test-vpalm-interpolate_points.jl"))
        include(joinpath(dirtest, "test-vpalm-bend.jl"))
        include(joinpath(dirtest, "test-vpalm-inertia_flex_rota.jl"))
        include(joinpath(dirtest, "test-vpalm-xyz_dist_angles.jl"))
    end

    @testset "Static mockup" begin
        include(joinpath(dirtest, "test-vpalm-static_mockup.jl"))
    end
end
