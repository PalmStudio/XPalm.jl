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
const VPALM_BENCHMARK_BIOMASS_FIELDS = (
    (name=:leaf_biomass, scale=:Leaf, variable=:biomass),
    (name=:leaflet_biomass, scale=:Leaf, variable=:biomass_leaflets),
    (name=:rachis_biomass, scale=:Leaf, variable=:biomass_rachis),
    (name=:petiole_biomass, scale=:Leaf, variable=:biomass_petiole),
    (name=:internode_biomass, scale=:Internode, variable=:biomass),
    (name=:male_biomass, scale=:Male, variable=:biomass),
    (name=:female_biomass, scale=:Female, variable=:biomass),
    (name=:stalk_biomass, scale=:Female, variable=:biomass_stalk),
    (name=:fruit_biomass, scale=:Female, variable=:biomass_fruits),
    (name=:oil_biomass, scale=:Female, variable=:biomass_oil),
    (name=:non_oil_biomass, scale=:Female, variable=:biomass_non_oil),
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

function _benchmark_biomass_checkpoint(simulation)
    scales = unique(field.scale for field in VPALM_BENCHMARK_BIOMASS_FIELDS)
    objects_by_scale = Dict(
        scale => sort!(
            collect(model_objects(simulation.model; scale=scale));
            by=object -> object.id.value,
        ) for scale in scales
    )
    totals = map(VPALM_BENCHMARK_BIOMASS_FIELDS) do field
        sum(
            Float64(getproperty(object.status, field.variable))
            for object in objects_by_scale[field.scale];
            init=0.0,
        )
    end
    names = Tuple(field.name for field in VPALM_BENCHMARK_BIOMASS_FIELDS)
    return merge(
        (timestep=current_step(simulation),),
        NamedTuple{names}(Tuple(totals)),
    )
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

function _run_benchmark_simulation(
    scene,
    palm,
    nsteps,
    architecture;
    collect_biomass=false,
    outputs=_benchmark_output_requests(),
)
    first_steps = min(VPALM_BENCHMARK_CHUNK, nsteps)
    first_run = @timed run!(
        scene;
        steps=first_steps,
        outputs=outputs,
    )
    simulation = first_run.value
    run_seconds = first_run.time
    run_bytes = first_run.bytes
    run_gc_seconds = first_run.gctime
    sampled_peak_pse_objects = length(model_objects(simulation.model))
    sampled_peak_mtg_nodes = length(palm.mtg)
    biomass_checkpoints = collect_biomass ?
                          [_benchmark_biomass_checkpoint(simulation)] :
                          NamedTuple[]
    _benchmark_progress(
        "architecture=$architecture: $(current_step(simulation)) / $nsteps days",
    )

    while current_step(simulation) < nsteps
        _benchmark_cancelled() && error("VPalm geometry benchmark cancelled")
        remaining = nsteps - current_step(simulation)
        continuation = @timed continue!(
            simulation;
            steps=min(VPALM_BENCHMARK_CHUNK, remaining),
        )
        run_seconds += continuation.time
        run_bytes += continuation.bytes
        run_gc_seconds += continuation.gctime
        sampled_peak_pse_objects = max(
            sampled_peak_pse_objects,
            length(model_objects(simulation.model)),
        )
        sampled_peak_mtg_nodes = max(sampled_peak_mtg_nodes, length(palm.mtg))
        collect_biomass && push!(
            biomass_checkpoints,
            _benchmark_biomass_checkpoint(simulation),
        )
        _benchmark_progress(
            "architecture=$architecture: $(current_step(simulation)) / $nsteps days",
        )
    end

    return (;
        simulation,
        sampled_peak_pse_objects,
        sampled_peak_mtg_nodes,
        biomass_checkpoints,
        run=(
            time=run_seconds,
            bytes=run_bytes,
            gctime=run_gc_seconds,
        ),
    )
end

function _run_benchmark_variant(
    architecture,
    weather,
    parameters;
    validate_biomass=true,
)
    if architecture
        XPalm.load_vpalm!()
    end

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
    simulation = _run_benchmark_simulation(
        setup.value.scene,
        setup.value.palm,
        nrow(weather),
        architecture,
    )

    GC.gc()
    postprocess = @timed _benchmark_output_values(
        simulation.simulation,
        nrow(weather),
    )

    validation = if validate_biomass
        GC.gc()
        @timed begin
            validation_palm = XPalm.Palm(
                initiation_age=0,
                parameters=deepcopy(parameters),
                architecture=architecture,
            )
            validation_scene = XPalm.xpalm_scene(
                validation_palm;
                architecture=architecture,
                environment=copy(weather),
            )
            _run_benchmark_simulation(
                validation_scene,
                validation_palm,
                nrow(weather),
                architecture;
                collect_biomass=true,
                outputs=:none,
            ).biomass_checkpoints
        end
    else
        (value=NamedTuple[], time=0.0, bytes=0, gctime=0.0)
    end

    return (
        architecture=architecture,
        palm=setup.value.palm,
        simulation=simulation.simulation,
        values=postprocess.value,
        setup=setup,
        run=simulation.run,
        validation=validation,
        postprocess=postprocess,
        pse_objects=length(model_objects(simulation.simulation.model)),
        mtg_nodes=length(setup.value.palm.mtg),
        sampled_peak_pse_objects=simulation.sampled_peak_pse_objects,
        sampled_peak_mtg_nodes=simulation.sampled_peak_mtg_nodes,
        biomass_checkpoints=validation.value,
        class_counts=_benchmark_class_counts(setup.value.palm.mtg),
    )
end


function _biomass_parity_table(without_architecture, with_architecture)
    left = without_architecture.biomass_checkpoints
    right = with_architecture.biomass_checkpoints
    length(left) == length(right) || error(
        "Architecture variants produced different biomass checkpoint counts",
    )
    for (left_checkpoint, right_checkpoint) in zip(left, right)
        left_checkpoint.timestep == right_checkpoint.timestep || error(
            "Architecture variants produced different biomass checkpoint timesteps: " *
            "$(left_checkpoint.timestep) and $(right_checkpoint.timestep)",
        )
    end

    return DataFrame([
        begin
            left_value = getproperty(left_checkpoint, field.name)
            right_value = getproperty(right_checkpoint, field.name)
            (
                timestep=left_checkpoint.timestep,
                variable=field.name,
                without_architecture=left_value,
                with_architecture=right_value,
                exact=isequal(left_value, right_value),
                absolute_difference=abs(right_value - left_value),
            )
        end for (left_checkpoint, right_checkpoint) in zip(left, right)
        for field in VPALM_BENCHMARK_BIOMASS_FIELDS
    ])
end

function _warm_benchmark(architecture, weather, parameters)
    _run_benchmark_variant(
        architecture,
        weather,
        parameters;
        validate_biomass=false,
    )
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
        validation_seconds=result.validation.time,
        validation_bytes=result.validation.bytes,
        validation_gc_seconds=result.validation.gctime,
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

function _environment_table(nsteps, warmup_steps, weather, measurement_order)
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
        "warm false, warm true, measure " *
        join(string.(measurement_order), ", measure "),
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
    run_vpalm_geometry_benchmark(
        output_directory;
        nsteps=40,
        warmup_steps=128,
        order=(false, true),
    )

Run a warmed, paired XPalm comparison with and without explicit VPalm
architecture. Results are written outside the repository as five CSV files:
phase timings/allocations, exact daily-output parity, biomass parity, topology
counts and environment fingerprints. Biomass checkpoints come from an
independent second simulation reported separately from simulation time. A daily
difference CSV is also written if exact daily-output parity fails.
"""
function run_vpalm_geometry_benchmark(
    output_directory;
    nsteps=40,
    warmup_steps=VPALM_BENCHMARK_WARMUP_STEPS,
    order=(false, true),
)
    nsteps > 0 || throw(ArgumentError("nsteps must be positive"))
    warmup_steps > 0 || throw(ArgumentError("warmup_steps must be positive"))
    measurement_order = Tuple(order)
    length(measurement_order) == 2 &&
        all(architecture -> architecture isa Bool, measurement_order) &&
        Set(measurement_order) == Set((false, true)) || throw(
        ArgumentError("order must contain false and true exactly once"),
    )
    output_directory = abspath(output_directory)
    mkpath(output_directory)

    weather_with_warmup = _benchmark_weather(
        max(nsteps, warmup_steps),
    )
    weather = first(weather_with_warmup, nsteps)
    warmup_weather = first(
        weather_with_warmup,
        min(warmup_steps, nrow(weather_with_warmup)),
    )
    parameters = _benchmark_parameters()

    _warm_benchmark(false, warmup_weather, parameters)
    _warm_benchmark(true, warmup_weather, parameters)

    results = Tuple(
        _run_benchmark_variant(architecture, weather, parameters)
        for architecture in measurement_order
    )
    without_architecture = only(result for result in results if !result.architecture)
    with_architecture = only(result for result in results if result.architecture)

    summary = DataFrame(_summary_row.(results))
    parity = _parity_table(without_architecture, with_architecture, weather)
    biomass_parity = _biomass_parity_table(
        without_architecture,
        with_architecture,
    )
    topology = _topology_table(results)
    environment = _environment_table(
        nsteps,
        nrow(warmup_weather),
        weather,
        measurement_order,
    )

    CSV.write(joinpath(output_directory, "phase_summary.csv"), summary)
    CSV.write(joinpath(output_directory, "output_parity.csv"), parity)
    CSV.write(joinpath(output_directory, "biomass_parity.csv"), biomass_parity)
    CSV.write(joinpath(output_directory, "topology_counts.csv"), topology)
    CSV.write(joinpath(output_directory, "environment.csv"), environment)

    output_exact = all(parity.exact)
    biomass_exact = all(biomass_parity.exact)
    difference_path = joinpath(output_directory, "daily_difference.csv")
    if !output_exact
        daily_difference = _daily_difference_table(
            without_architecture,
            with_architecture,
            weather,
        )
        CSV.write(difference_path, daily_difference)
    elseif isfile(difference_path)
        rm(difference_path)
    end

    if !(output_exact && biomass_exact)
        error(
            "Architecture changed observer outputs; inspect " *
            joinpath(output_directory, "output_parity.csv") *
            ", " *
            joinpath(output_directory, "biomass_parity.csv") *
            (output_exact ? "" : ", and $difference_path"),
        )
    end

    return (
        output_directory=output_directory,
        summary=summary,
        parity=parity,
        biomass_parity=biomass_parity,
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
