using Test

const reference_regression_only =
    length(ARGS) == 1 &&
    only(ARGS) == "reference-regression"

if reference_regression_only
using XPalm
using Test
using Dates
using SHA
using TOML
using PlantSimEngine
using CSV
using DataFrames
using Statistics

const dirtest = @__DIR__
include("reference_regression_helpers.jl")
include("test-reference-regression.jl")
else
using XPalm
using XPalm.Models
const VPalm = XPalm.load_vpalm!()
const read_parameters = VPalm.read_parameters
import XPalm: Palm
using Aqua
using JET
using GeometryBasics
using CairoMakie
using ReferenceTests
using Test
using Dates
using Random
using SHA
using TOML
import StableRNGs: StableRNG
using MultiScaleTreeGraph, PlantGeom, PlantMeteo, PlantSimEngine
import PlantSimEngine:
    AppliesTo,
    Calls,
    Inputs,
    Many,
    ModelSpec,
    Object,
    One,
    OptionalOne,
    OutputRequest,
    PreviousTimeStep,
    CompositeModel,
    SceneScope,
    Self,
    SelfPlant,
    Status,
    TimeStep,
    collect_outputs,
    explain_bindings,
    process,
    run!,
    model_objects
using CSV, DataFrames, Statistics, Unitful
# Import the meteo data once:

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
if :duration ∉ names(meteo)
    meteo.duration = fill(Day(1), nrow(meteo))
end

dirtest = joinpath(dirname(dirname(pathof(XPalm))), "test/")

function test_scene(
    scale::Symbol,
    models::PlantSimEngine.AbstractModel...;
    status=Status(),
    environment=nothing,
)
    applications = Tuple(
        ModelSpec(model; name=process(model)) |>
        AppliesTo(One(scale=scale))
        for model in models
    )
    kind = scale == :Soil ? :soil : :plant
    return CompositeModel(
        Object(:test_object; scale=scale, kind=kind, status=status);
        applications=applications,
        environment=environment,
    )
end

test_status(scene, scale::Symbol) = only(model_objects(scene; scale=scale)).status

function output_values(sim, name::Symbol)
    return [row.value for row in collect_outputs(sim, name; sink=nothing)]
end

# VPalm parameters
vpalm_parameters = read_parameters(joinpath(dirtest, "references", "vpalm-parameter_file.yml"))
vpalm_parameters2 = read_parameters(joinpath(dirtest, "references", "vpalm-parameter_file-missing_rachis_final_lengths.yml"))

# @testset "Code quality (Aqua.jl)" begin
#     Aqua.test_all(
#         XPalm;
#         ambiguities=false,
#         stale_deps=(; ignore=[:CoordinateTransformations, :GeometryBasics, :Interpolations, :Rotations]),
#     )
# end

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

@testset "Carbon_allocation" begin
    include(joinpath(dirtest, "test-carbon_allocation.jl"))
end

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

if lowercase(get(ENV, "XPALM_RUN_REFERENCE_REGRESSION", "false")) in
   ("1", "true", "yes")
    include("reference_regression_helpers.jl")
    include("test-reference-regression.jl")
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
end
