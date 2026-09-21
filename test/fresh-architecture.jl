# Run each case in its own process. Loading VPalm explicitly, or running another
# architecture case first, would hide the first-use world-age regression.
using Test
using XPalm
using CSV, DataFrames
import MultiScaleTreeGraph
import PlantSimEngine

function short_weather()
    CSV.read(joinpath(pkgdir(XPalm), "0-data", "meteo.csv"), DataFrame; limit=3)
end

function check_direct_palm()
    palm = XPalm.Palm(architecture=true)
    @test palm isa XPalm.Palm
    @test haskey(MultiScaleTreeGraph.node_attributes(palm.mtg), :vpalm_rng)
    stem = only(MultiScaleTreeGraph.descendants(palm.mtg; symbol=:Stem))
    @test stem[:stem_height] > zero(stem[:stem_height])
    leaf = only(MultiScaleTreeGraph.descendants(palm.mtg; symbol=:Leaf))
    @test leaf[:is_alive]
end

function check_model_applications()
    palm = XPalm.Palm()
    applications = XPalm.model_applications(palm; architecture=true)
    names = PlantSimEngine.application_name.(applications)
    @test :Leaf__fresh_biomass in names
    @test :Internode__geometry in names
    @test length(unique(names)) == length(names)
end

function check_xpalm_sink()
    weather = short_weather()
    result = XPalm.xpalm(weather, DataFrame; architecture=true)
    @test only(keys(result)) == :Scene
    @test nrow(result[:Scene]) == 3
    @test all(isfinite, result[:Scene].lai)
    # Architecture observes physiology; it must not alter the LAI trajectory.
    baseline = XPalm.xpalm(weather, DataFrame; architecture=false)
    @test result[:Scene].lai == baseline[:Scene].lai
end

function check_xpalm_simulation()
    weather = short_weather()
    result = XPalm.xpalm(weather; architecture=true)
    @test result isa PlantSimEngine.Simulation
    rows = PlantSimEngine.collect_outputs(result, :Scene__lai; sink=nothing)
    @test length(rows) == 3
    @test all(row -> isfinite(row.value), rows)
    baseline = XPalm.xpalm(weather; architecture=false)
    baseline_rows = PlantSimEngine.collect_outputs(baseline, :Scene__lai; sink=nothing)
    @test [row.value for row in rows] == [row.value for row in baseline_rows]
end

function check_physiology_only()
    palm = XPalm.Palm()
    @test !haskey(MultiScaleTreeGraph.node_attributes(palm.mtg), :vpalm_rng)
    names = PlantSimEngine.application_name.(XPalm.model_applications(palm))
    @test :Leaf__fresh_biomass ∉ names
    @test :Internode__geometry ∉ names
    result = XPalm.xpalm(short_weather(), DataFrame; palm=palm)
    @test result[:Scene].lai[1] == 0.000272
    @test all(isfinite, result[:Scene].lai)
    @test all(package.name ∉ ("GLMakie", "CairoMakie", "WGLMakie")
              for package in keys(Base.loaded_modules))
end

cases = Dict(
    "palm" => check_direct_palm,
    "applications" => check_model_applications,
    "sink" => check_xpalm_sink,
    "simulation" => check_xpalm_simulation,
    "physiology" => check_physiology_only,
)
case = only(ARGS)
@testset "Fresh compiled public call: $case" begin
    cases[case]()
end
