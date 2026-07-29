using CSV
using DataFrames
using Dates
using PlantSimEngine
using SHA
using TOML
using XPalm

include(joinpath(@__DIR__, "..", "test", "reference_regression_helpers.jl"))

function git_revision(path)
    try
        return readchomp(`git -C $path rev-parse HEAD`)
    catch
        return "unknown"
    end
end

sha256_file(path) = bytes2hex(SHA.sha256(read(path)))

function write_reference_regression(output_dir)
    expected_files = (
        "trajectory_checkpoints.csv",
        "harvest_events.csv",
        "summary.csv",
        "metadata.toml",
    )
    existing = filter(file -> isfile(joinpath(output_dir, file)), expected_files)
    allow_update =
        lowercase(get(ENV, "XPALM_UPDATE_REFERENCE", "false")) in
        ("1", "true", "yes")
    isempty(existing) || allow_update || error(
        "Refusing to overwrite reference files. Set XPALM_UPDATE_REFERENCE=true " *
        "for an intentional baseline update.",
    )

    mkpath(output_dir)
    package_root = dirname(dirname(pathof(XPalm)))
    meteo_path = joinpath(package_root, "0-data", "meteo.csv")
    manifest_path = joinpath(dirname(Base.active_project()), "Manifest.toml")
    scenario = run_reference_regression_scenario(; meteo_path=meteo_path)

    CSV.write(
        joinpath(output_dir, "trajectory_checkpoints.csv"),
        scenario.tables.trajectory,
    )
    CSV.write(
        joinpath(output_dir, "harvest_events.csv"),
        scenario.tables.harvest_events,
    )
    CSV.write(joinpath(output_dir, "summary.csv"), scenario.tables.summary)

    parameters = XPalm.default_parameters()
    metadata = Dict(
        "source" => Dict(
            "xpalm_tag" => "v$(Base.pkgversion(XPalm))",
            "xpalm_commit" => git_revision(package_root),
            "parameter_source" => "XPalm.default_parameters()",
        ),
        "environment" => Dict(
            "julia_version" => string(VERSION),
            "plantsimengine_version" => string(Base.pkgversion(PlantSimEngine)),
            "manifest_sha256" => isfile(manifest_path) ?
                sha256_file(manifest_path) : "missing",
        ),
        "inputs" => Dict(
            "meteo_file" => "0-data/meteo.csv",
            "meteo_sha256" => sha256_file(meteo_path),
            "start_date" => string(first(scenario.meteo.date)),
            "end_date" => string(last(scenario.meteo.date)),
            "nsteps" => nrow(scenario.meteo),
        ),
        "stochastic_configuration" => Dict(
            "sex_determination_seed" =>
                parameters["reproduction"]["sex_ratio"]["random_seed"],
            "abortion_seed" =>
                parameters["reproduction"]["abortion"]["random_seed"],
        ),
        "fixture" => Dict(
            "checkpoint_policy" =>
                "first day, every calendar-month first day, and final day",
            "elapsed_seconds" => scenario.elapsed,
            "generated_at" => string(Dates.now()),
        ),
    )
    open(joinpath(output_dir, "metadata.toml"), "w") do io
        TOML.print(io, metadata; sorted=true)
        println(io)
    end

    return scenario
end

output_dir = isempty(ARGS) ?
    joinpath(@__DIR__, "..", "test", "references", "regression", "v0.6.1") :
    only(ARGS)

scenario = write_reference_regression(normpath(output_dir))
@info "XPalm reference regression fixture written" output_dir elapsed_seconds =
    scenario.elapsed
