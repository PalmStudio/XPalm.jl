using CSV
using DataFrames
using Dates
using MultiScaleTreeGraph
using PlantGeom
using PlantSimEngine
using SHA
using Statistics
using XPalm

import PlantSimEngine:
    OutputRequest, collect_outputs, continue!, current_step, model_objects, run!

const VPALM_BENCHMARK_SEED = 20260830
const VPALM_BENCHMARK_CHUNK = 128
const VPALM_BENCHMARK_WARMUP_STEPS = 128
const VPALM_BENCHMARK_OUTPUTS = (
    (scale=:Scene, variable=:lai, application=:Scene__lai_dynamic, name=:scene_lai),
    (
        scale=:Scene,
        variable=:leaf_area,
        application=:Scene__lai_dynamic,
        name=:scene_leaf_area,
    ),
    (
        scale=:Scene,
        variable=:aPPFD,
        application=:Scene__light_interception,
        name=:scene_aPPFD,
    ),
    (
        scale=:Plant,
        variable=:plant_age,
        application=:Plant__plant_age,
        name=:plant_age,
    ),
    (
        scale=:Plant,
        variable=:leaf_area,
        application=:Plant__leaf_area,
        name=:plant_leaf_area,
    ),
    (
        scale=:Plant,
        variable=:Rm,
        application=:Plant__maintenance_respiration,
        name=:plant_Rm,
    ),
    (
        scale=:Plant,
        variable=:carbon_assimilation,
        application=:Plant__carbon_assimilation,
        name=:plant_carbon_assimilation,
    ),
    (
        scale=:Plant,
        variable=:carbon_offer_after_rm,
        application=:Plant__carbon_offer,
        name=:carbon_offer_after_rm,
    ),
    (
        scale=:Plant,
        variable=:carbon_demand,
        application=:Plant__carbon_allocation,
        name=:plant_carbon_demand,
    ),
    (
        scale=:Plant,
        variable=:carbon_allocation,
        application=:Plant__carbon_allocation,
        name=:plant_carbon_allocation,
    ),
    (
        scale=:Plant,
        variable=:carbon_offer_after_allocation,
        application=:Plant__carbon_allocation,
        name=:carbon_offer_after_allocation,
    ),
    (
        scale=:Plant,
        variable=:reserve,
        application=:Plant__reserve_filling,
        name=:plant_reserve,
    ),
    (
        scale=:Plant,
        variable=:phytomer_count,
        application=:Plant__phytomer_emission,
        name=:phytomer_count,
    ),
    (
        scale=:Plant,
        variable=:biomass_bunch_harvested,
        application=:Plant__harvest,
        name=:biomass_bunch_harvested,
    ),
    (
        scale=:Plant,
        variable=:biomass_bunch_harvested_cum,
        application=:Plant__harvest,
        name=:biomass_bunch_harvested_cum,
    ),
    (
        scale=:Plant,
        variable=:n_bunches_harvested,
        application=:Plant__harvest,
        name=:n_bunches_harvested,
    ),
    (
        scale=:Plant,
        variable=:n_bunches_harvested_cum,
        application=:Plant__harvest,
        name=:n_bunches_harvested_cum,
    ),
    (
        scale=:Plant,
        variable=:biomass_oil_harvested,
        application=:Plant__harvest,
        name=:biomass_oil_harvested,
    ),
    (
        scale=:Plant,
        variable=:biomass_oil_harvested_cum,
        application=:Plant__harvest,
        name=:biomass_oil_harvested_cum,
    ),
    (
        scale=:Soil,
        variable=:ftsw,
        application=:Soil__soil_water,
        name=:soil_ftsw,
    ),
    (
        scale=:Soil,
        variable=:root_depth,
        application=:Soil__root_growth,
        name=:soil_root_depth,
    ),
)
const VPALM_BENCHMARK_CLASSES = (
    :Petiole,
    :PetioleSegment,
    :Rachis,
    :RachisSegment,
    :Leaflet,
)

function _benchmark_weather(nsteps)
    path = joinpath(dirname(dirname(pathof(XPalm))), "0-data", "meteo.csv")
    weather = CSV.read(path, DataFrame)
    nsteps <= nrow(weather) ||
        throw(ArgumentError("Requested $nsteps steps but weather has $(nrow(weather)) rows"))
    weather = weather[1:nsteps, :]
    :duration in propertynames(weather) ||
        (weather.duration = fill(Day(1), nrow(weather)))
    return weather
end

function _benchmark_output_requests()
    return [
        OutputRequest(
            output.scale,
            output.variable;
            application=output.application,
            name=output.name,
        ) for output in VPALM_BENCHMARK_OUTPUTS
    ]
end

function _benchmark_output_values(simulation, nsteps)
    return Dict(
        output.name => begin
            rows = collect_outputs(simulation, output.name; sink=nothing)
            sort!(rows; by=row -> (row.timestep, row.object_id))
            length(rows) == nsteps || error(
                "Expected $nsteps values for $(output.name), received $(length(rows))",
            )
            timesteps = [row.timestep for row in rows]
            timesteps == collect(1:nsteps) || error(
                "Output $(output.name) does not contain exactly one row per timestep",
            )
            object_ids = unique([row.object_id for row in rows])
            length(object_ids) == 1 || error(
                "Output $(output.name) contains $(length(object_ids)) objects; expected one",
            )
            [row.value for row in rows]
        end for output in VPALM_BENCHMARK_OUTPUTS
    )
end

function _benchmark_class_counts(mtg)
    counts = Dict(class => 0 for class in VPALM_BENCHMARK_CLASSES)
    traverse!(mtg) do node
        class = symbol(node)
        haskey(counts, class) && (counts[class] += 1)
        return nothing
    end
    return counts
end

function _benchmark_parameters()
    parameters = XPalm.default_parameters()
    parameters["vpalm"]["seed"] = VPALM_BENCHMARK_SEED
    return parameters
end

_benchmark_progress(message) = if isdefined(Main, :KaimonGate)
    Main.KaimonGate.progress(message)
else
    nothing
end

_benchmark_cancelled() =
    isdefined(Main, :KaimonGate) && Main.KaimonGate.is_cancelled()

function _run_benchmark_simulation(scene, palm, nsteps, architecture)
    first_steps = min(VPALM_BENCHMARK_CHUNK, nsteps)
    simulation = run!(
        scene;
        steps=first_steps,
        outputs=_benchmark_output_requests(),
    )
    sampled_peak_pse_objects = length(model_objects(simulation.model))
    sampled_peak_mtg_nodes = length(palm.mtg)
    _benchmark_progress(
        "architecture=$architecture: $(current_step(simulation)) / $nsteps days",
    )

    while current_step(simulation) < nsteps
        _benchmark_cancelled() && error("VPalm geometry benchmark cancelled")
        remaining = nsteps - current_step(simulation)
        continue!(simulation; steps=min(VPALM_BENCHMARK_CHUNK, remaining))
        sampled_peak_pse_objects = max(
            sampled_peak_pse_objects,
            length(model_objects(simulation.model)),
        )
        sampled_peak_mtg_nodes = max(sampled_peak_mtg_nodes, length(palm.mtg))
        _benchmark_progress(
            "architecture=$architecture: $(current_step(simulation)) / $nsteps days",
        )
    end

    return (; simulation, sampled_peak_pse_objects, sampled_peak_mtg_nodes)
end

function _run_benchmark_variant(architecture, weather, parameters)
    GC.gc()
    setup = @timed begin
        palm = XPalm.Palm(
            initiation_age=0,
            parameters=deepcopy(parameters),
            architecture=architecture,
        )
        scene = XPalm.xpalm_scene(
            palm;
            architecture=architecture,
            environment=copy(weather),
        )
        (; palm, scene)
    end

    GC.gc()
    simulation = @timed _run_benchmark_simulation(
        setup.value.scene,
        setup.value.palm,
        nrow(weather),
        architecture,
    )

    GC.gc()
    postprocess = @timed _benchmark_output_values(
        simulation.value.simulation,
        nrow(weather),
    )

    return (
        architecture=architecture,
        palm=setup.value.palm,
        simulation=simulation.value.simulation,
        values=postprocess.value,
        setup=setup,
        run=simulation,
        postprocess=postprocess,
        pse_objects=length(model_objects(simulation.value.simulation.model)),
        mtg_nodes=length(setup.value.palm.mtg),
        sampled_peak_pse_objects=simulation.value.sampled_peak_pse_objects,
        sampled_peak_mtg_nodes=simulation.value.sampled_peak_mtg_nodes,
        class_counts=_benchmark_class_counts(setup.value.palm.mtg),
    )
end

function _warm_benchmark(architecture, weather, parameters)
    _run_benchmark_variant(architecture, weather, parameters)
    return nothing
end

function _max_absolute_difference(left, right)
    length(left) == length(right) || return Inf
    isempty(left) && return 0.0
    return maximum(abs(Float64(a) - Float64(b)) for (a, b) in zip(left, right))
end

function _parity_table(without_architecture, with_architecture, weather)
    variables = sort!(collect(keys(without_architecture.values)))
    return DataFrame([
        begin
            left = without_architecture.values[variable]
            right = with_architecture.values[variable]
            mismatches = map((a, b) -> !isequal(a, b), left, right)
            first_difference = findfirst(mismatches)
            (
                variable=variable,
                count_without=length(left),
                count_with=length(right),
                exact=isnothing(first_difference),
                maximum_absolute_difference=_max_absolute_difference(left, right),
                first_different_timestep=isnothing(first_difference) ?
                    missing : first_difference,
                first_different_date=isnothing(first_difference) ?
                    missing : weather.date[first_difference],
            )
        end for variable in variables
    ])
end

function _daily_difference_table(without_architecture, with_architecture, weather)
    daily = DataFrame(date=weather.date, timestep=collect(1:nrow(weather)))
    for variable in sort!(collect(keys(without_architecture.values)))
        left = without_architecture.values[variable]
        right = with_architecture.values[variable]
        daily[!, Symbol("false__", variable)] = left
        daily[!, Symbol("true__", variable)] = right
        daily[!, Symbol("delta__", variable)] = right .- left
    end
    return daily
end

function _summary_row(result)
    return (
        architecture=result.architecture,
        setup_seconds=result.setup.time,
        setup_bytes=result.setup.bytes,
        setup_gc_seconds=result.setup.gctime,
        simulation_seconds=result.run.time,
        simulation_bytes=result.run.bytes,
        simulation_gc_seconds=result.run.gctime,
        postprocess_seconds=result.postprocess.time,
        postprocess_bytes=result.postprocess.bytes,
        postprocess_gc_seconds=result.postprocess.gctime,
        pse_objects=result.pse_objects,
        mtg_nodes=result.mtg_nodes,
        sampled_peak_pse_objects=result.sampled_peak_pse_objects,
        sampled_peak_mtg_nodes=result.sampled_peak_mtg_nodes,
    )
end

function _topology_table(results)
    return DataFrame([
        (
            architecture=result.architecture,
            class=class,
            count=result.class_counts[class],
        ) for result in results for class in VPALM_BENCHMARK_CLASSES
    ])
end

function _git_head(path)
    try
        return String(readchomp(`git -C $path rev-parse HEAD`))
    catch
        return "unknown"
    end
end

function _git_state(path)
    try
        return (
            dirty=!isempty(
                readchomp(`git -C $path status --porcelain --untracked-files=no`),
            ),
            known=true,
        )
    catch
        return (; dirty=false, known=false)
    end
end

function _active_project_fingerprint()
    active_project = something(Base.active_project(), "unknown")
    manifest_path = joinpath(dirname(active_project), "Manifest.toml")
    manifest_sha256 = isfile(manifest_path) ?
        bytes2hex(sha256(read(manifest_path))) :
        "missing"
    return (; active_project, manifest_path, manifest_sha256)
end

function _environment_table(nsteps, warmup_steps, weather)
    packages = (XPalm, PlantSimEngine, MultiScaleTreeGraph, PlantGeom)
    rows = [
        let source_path = dirname(dirname(pathof(package)))
            git_state = _git_state(source_path)
            (
                component=string(nameof(package)),
                version=string(Base.pkgversion(package)),
                source_path=source_path,
                git_head=_git_head(source_path),
                git_dirty=git_state.dirty,
                git_state_known=git_state.known,
            )
        end for package in packages
    ]
    push!(
        rows,
        (
            component="Julia",
            version=string(VERSION),
            source_path=Sys.BINDIR,
            git_head="not-applicable",
            git_dirty=false,
            git_state_known=false,
        ),
    )
    project = _active_project_fingerprint()
    environment = DataFrame(rows)
    environment.nsteps = fill(nsteps, nrow(environment))
    environment.seed = fill(VPALM_BENCHMARK_SEED, nrow(environment))
    environment.threads = fill(Threads.nthreads(), nrow(environment))
    environment.cpu = fill(Sys.CPU_NAME, nrow(environment))
    environment.kernel = fill(Sys.KERNEL, nrow(environment))
    environment.machine_arch = fill(Sys.ARCH, nrow(environment))
    environment.warmup_steps = fill(warmup_steps, nrow(environment))
    environment.sample_count = fill(1, nrow(environment))
    environment.sample_order = fill(
        "warm false, warm true, measure false, measure true",
        nrow(environment),
    )
    environment.parameter_source = fill(
        "XPalm.default_parameters() with fixed vpalm.seed",
        nrow(environment),
    )
    environment.active_project = fill(project.active_project, nrow(environment))
    environment.manifest_path = fill(project.manifest_path, nrow(environment))
    environment.manifest_sha256 = fill(project.manifest_sha256, nrow(environment))
    environment.start_date = fill(first(weather.date), nrow(environment))
    environment.end_date = fill(last(weather.date), nrow(environment))
    return environment
end

"""
    run_vpalm_geometry_benchmark(output_directory; nsteps=40)

Run a warmed, paired XPalm comparison with and without explicit VPalm
architecture. Results are written outside the repository as four CSV files:
phase timings/allocations, exact output parity, topology counts and environment
fingerprints. A daily difference CSV is also written if exact parity fails.
"""
function run_vpalm_geometry_benchmark(output_directory; nsteps=40)
    nsteps > 0 || throw(ArgumentError("nsteps must be positive"))
    output_directory = abspath(output_directory)
    mkpath(output_directory)

    weather_with_warmup = _benchmark_weather(
        max(nsteps, VPALM_BENCHMARK_WARMUP_STEPS),
    )
    weather = first(weather_with_warmup, nsteps)
    warmup_weather = first(
        weather_with_warmup,
        min(VPALM_BENCHMARK_WARMUP_STEPS, nrow(weather_with_warmup)),
    )
    parameters = _benchmark_parameters()

    _warm_benchmark(false, warmup_weather, parameters)
    _warm_benchmark(true, warmup_weather, parameters)

    without_architecture = _run_benchmark_variant(false, weather, parameters)
    with_architecture = _run_benchmark_variant(true, weather, parameters)
    results = (without_architecture, with_architecture)

    summary = DataFrame(_summary_row.(results))
    parity = _parity_table(without_architecture, with_architecture, weather)
    topology = _topology_table(results)
    environment = _environment_table(nsteps, nrow(warmup_weather), weather)

    CSV.write(joinpath(output_directory, "phase_summary.csv"), summary)
    CSV.write(joinpath(output_directory, "output_parity.csv"), parity)
    CSV.write(joinpath(output_directory, "topology_counts.csv"), topology)
    CSV.write(joinpath(output_directory, "environment.csv"), environment)

    if !all(parity.exact)
        daily_difference = _daily_difference_table(
            without_architecture,
            with_architecture,
            weather,
        )
        difference_path = joinpath(output_directory, "daily_difference.csv")
        CSV.write(difference_path, daily_difference)
        error(
            "Architecture changed observer outputs; inspect " *
            joinpath(output_directory, "output_parity.csv") *
            " and $difference_path",
        )
    end

    return (
        output_directory=output_directory,
        summary=summary,
        parity=parity,
        topology=topology,
        environment=environment,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    output_directory = isempty(ARGS) ?
        mktempdir(prefix="xpalm-vpalm-geometry-") :
        ARGS[1]
    nsteps = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 40
    result = run_vpalm_geometry_benchmark(output_directory; nsteps=nsteps)
    @info "VPalm geometry benchmark completed" output_directory=result.output_directory
end
