

"""
    xpalm(meteo; vars=Dict(:Scene => (:lai,)), architecture=false, palm=Palm(initiation_age=0, parameters=default_parameters()))
    xpalm(meteo, sink; vars=Dict(:Scene => (:lai,)), architecture=false, palm=Palm(initiation_age=0, parameters=default_parameters()))

Run the XPalm model with the given meteo data and return the results in a DataFrame.

# Arguments

- `meteo`: DataFrame with the meteo data
- `sink`: a `Tables.jl` compatible sink function to format the results, for exemple a `DataFrame`
- `vars`: A dictionary with the outputs to be returned for each scale of simulation
- `architecture`: A boolean indicating whether to compute the 3D architecture of the palm (default is false)
- `palm`: the Palm object with the parameters of the model

# Returns

A `PlantSimEngine.Simulation`, or collected output rows when `sink` is supplied.

# Example

```julia
using XPalm, CSV, DataFrames
meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
df = xpalm(meteo, DataFrame; vars=Dict(:Scene => (:lai,)))
```
"""
function xpalm(meteo, sink; vars=Dict(:Scene => (:lai,)), architecture=false, palm=Palm(initiation_age=0, parameters=default_parameters(), architecture=architecture))
    meteo_with_duration = _ensure_meteo_duration(meteo)
    scene = xpalm_scene(palm; architecture=architecture, environment=meteo_with_duration)
    sim = PlantSimEngine.run!(
        scene;
        steps=_nsteps(meteo_with_duration),
        outputs=_output_requests(vars),
    )
    return _collect_xpalm_outputs(sim, sink, vars)
end

function xpalm(meteo; vars=Dict(:Scene => (:lai,)), architecture=false, palm=Palm(initiation_age=0, parameters=default_parameters(), architecture=architecture))
    meteo_with_duration = _ensure_meteo_duration(meteo)
    scene = xpalm_scene(palm; architecture=architecture, environment=meteo_with_duration)
    return PlantSimEngine.run!(
        scene;
        steps=_nsteps(meteo_with_duration),
        outputs=_output_requests(vars),
    )
end

function xpalm_scene(palm::Palm; architecture=false, environment=nothing)
    return PlantSimEngine.CompositeModel(
        palm.mtg;
        applications=model_applications(palm; architecture=architecture),
        environment=environment,
        status=_xpalm_initial_status,
    )
end

function _xpalm_initial_status(node)
    attrs = MultiScaleTreeGraph.node_attributes(node)
    status_data = Dict{Symbol,Any}()
    for (key, value) in pairs(attrs)
        key_symbol = Symbol(key)
        key_symbol == :plantsimengine_status && error(
            "XPalm cannot import the legacy `plantsimengine_status` MTG " *
            "attribute as runtime state. Remove it from the persisted graph " *
            "and resolve live status with `PlantSimEngine.model_status`.",
        )
        status_data[key_symbol] = value
    end
    if MultiScaleTreeGraph.symbol(node) in
       (:Phytomer, :Internode, :Leaf, :Male, :Female)
        defaults = (
            plant_age=-9999,
            initiation_age=0,
            TT_since_init=0.0,
            state=:undetermined,
            sex=:undetermined,
        )
        for (key, value) in pairs(defaults)
            get!(status_data, key, value)
        end
    end
    status_data[:node] = node
    return PlantSimEngine.Status((; status_data...))
end

function _output_requests(vars)
    isnothing(vars) && return :all
    requests = PlantSimEngine.OutputRequest[]
    for (scale, variables) in pairs(vars)
        for variable in variables
            scale_symbol = Symbol(scale)
            variable_symbol = Symbol(variable)
            push!(
                requests,
                PlantSimEngine.OutputRequest(
                    scale_symbol,
                    variable_symbol;
                    name=Symbol(scale_symbol, "__", variable_symbol),
                ),
            )
        end
    end
    return requests
end

function _collect_xpalm_outputs(sim, sink, vars)
    isempty(vars) && return Dict{Symbol,Any}()
    requested = PlantSimEngine.collect_outputs(sim; sink=nothing)
    rows_by_scale = Dict{Symbol,Dict{Tuple{Int,Any},Dict{Symbol,Any}}}()

    for rows in values(requested)
        for row in rows
            scale_rows = get!(rows_by_scale, row.scale) do
                Dict{Tuple{Int,Any},Dict{Symbol,Any}}()
            end
            row_key = (row.timestep, row.object_id)
            values_at_step = get!(scale_rows, row_key) do
                Dict{Symbol,Any}(
                    :timestep => row.timestep,
                    :node => row.object_id,
                )
            end
            values_at_step[row.variable] = row.value
        end
    end

    outputs = Dict{Symbol,Any}()
    for (scale, variables) in pairs(vars)
        scale_symbol = Symbol(scale)
        variable_names = Tuple(Symbol.(variables))
        fields = (:timestep, :node, variable_names...)
        scale_rows = get(
            rows_by_scale,
            scale_symbol,
            Dict{Tuple{Int,Any},Dict{Symbol,Any}}(),
        )
        row_keys = sort!(collect(keys(scale_rows)); by=key -> (key[1], string(key[2])))
        rows = [
            NamedTuple{fields}(
                Tuple(get(scale_rows[key], field, missing) for field in fields),
            )
            for key in row_keys
        ]
        outputs[scale_symbol] = sink(rows)
    end
    return outputs
end

function _nsteps(meteo)
    rows = Tables.rows(meteo)
    n = 0
    for _ in rows
        n += 1
    end
    return n
end

"""
    _ensure_meteo_duration(meteo)

Ensure each meteo row defines `duration` (required by recent PlantSimEngine versions).
When missing, default to a daily timestep (`Dates.Day(1)`).
"""
function _ensure_meteo_duration(meteo)
    rows = Tables.rows(meteo)
    first_state = iterate(rows)
    isnothing(first_state) && return meteo
    hasproperty(first_state[1], :duration) && return meteo

    rowtable = Tables.rowtable(meteo)
    return [merge(row, (duration=Dates.Day(1),)) for row in rowtable]
end
