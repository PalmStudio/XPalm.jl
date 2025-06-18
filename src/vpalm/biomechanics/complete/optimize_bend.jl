"""
    optimize_bend(field_data,
                elastic_modulus,
                shear_modulus,
                type,
                method,
                tol,
                nb_rep,
                kwargs...)

Optimize the elastic_modulus, the shear_modulus or both using observations.

# Arguments

- `field_data`: DataFrames, or list of DataFrames with the x, y and z coordinates of the observed points.
If list of DataFrames, each element correspond to a separate beam (e.g. each branch)
- `elastic_modulus`: Elasticity modulus (bending, MPa). Default is (1.0,10000.0).
See details.
- `shear_modulus`: Shear modulus (torsion, MPa). Default is (1.0,10000.0).
`See details.
- `type`: Type of optimization (either "bending","torsion" or "all"). Default is "all".
- `method`: Method to use when optimizing one parameter. Default is "L-BFGS-B".
See details.
- `tol`: Tolerance for optimization accuracy. Default is `eps()^0.25`.
- `nb_rep`: Number of starting points for the optimization algorithm. Default is 5.
- `kwargs...`: Further parameters to pass to `bend()`

# Details

The `elastic_modulus` and `shear_modulus` are either provided as a vector of min and max values if optimized,
or as a single value to force the parameter if not optimized.

# Returns

A NamedTuple with the following elements:
- `elastic_modulus`: the optimized elasticity modulus value
- `shear_modulus`: the optimized shear modulus value
- `init_values`: a DataFrames with the initial values used for each repetition
- `optim_values`: a DataFrames with the optimized values for each step
- `min_quadratic_error`: minimum quadratic error of all repetitions
- `rep_min_crit`: index of the repetition that gave the minimum quadratic error
- `plots`: plots of optimal value ~ initial value for each parameter to analyze the sensitivity of the optimized value to the starting points.

# Examples
```julia
file = joinpath(dirname(dirname(pathof(VPalm))), "test", "references", "6_EW01.22_17_kanan_unbent.csv")
fd = DataFrame(CSV.File(file))

```
"""
function optimize_bend(field_data;
    elastic_modulus=(1.0, 10000.0),
    shear_modulus=(1.0, 10000.0),
    type="all",
    method="L-BFGS-B",
    tol=eps()^0.25,
    nb_rep=5,
    kwargs...)

    # Check optimization type
    type ∈ ["all", "bending", "torsion"] || error("Must be either 'all', 'bending' or 'torsion'")

    # Required columns
    required_columns = ["x","y","z","distance",
         "type","width","height","inclination",
         "torsion","mass","mass_right","mass_left"]

    # Convert to dict if necessary
    field_data = field_data isa DataFrame ? Dict("sim1" => field_data) : field_data

    # Check if missing columns
    for df in values(field_data)
        missing_cols = setdiff(required_columns, names(df))
        isempty(missing_cols) || error("Missing columns: ", join(missing_cols, ", "))
    end

    # Compute unbend
    df_unbent = Dict(name => unbend(df) for (name, df) in field_data)

    # Add application distance fields
    for df in values(df_unbent)
        df.distance_application = distance_weight_sine(df.x)
    end

    # Start optimization
    optim_results = Vector{Any}(undef, nb_rep)

    if type != "all"
        # Univariate Optimisation
        if type == "bending"
            interval = elastic_modulus
            start_values = rand(nb_rep) .* (elastic_modulus[2] - elastic_modulus[1]) .+ elastic_modulus[1]
            y = shear_modulus[1]
            param_name = "elastic_modulus"
        else
            interval = shear_modulus
            start_values = rand(nb_rep) .* (shear_modulus[2] - shear_modulus[1]) .+ shear_modulus[1]
            y = elastic_modulus[1]
            param_name = "shear_modulus"
        end

        for irep in 1:nb_rep
            if method == "L-BFGS-B"
                try
                    optim_results[irep] = optimize(
                        x -> compute_error(x, y, field_data, df_unbent, type, kwargs...),
                        interval[1],
                        interval[2],
                        start_values[irep],
                        Fminbox(LBFGS()),
                        Optim.Options(rel_tol = tol)
                    )
                catch
                    @warn "L-BFGS-B optimization failed for repetition $irep"
                    optim_results[irep] = nothing
                end
            else
                try
                    optim_results[irep] = optimize(
                        x -> compute_error(x, y, field_data, df_unbent, type, kwargs...),
                        interval[1],
                        interval[2],
                        method=eval(Symbol(method)),
                        rel_tol=tol
                    )
                catch
                    @warn "Optimization with method $method failed for repetition $irep"
                    optim_results[irep] = nothing
                end
            end
        end
    else
        # Multivariate Optimisation
        start_values_elastic = rand(nb_rep) .* (elastic_modulus[2] - elastic_modulus[1]) .+ elastic_modulus[1]
        start_values_shear = rand(nb_rep) .* (shear_modulus[2] - shear_modulus[1]) .+ shear_modulus[1]
        param_name = ["elastic_modulus", "shear_modulus"]
        for irep in 1:nb_rep
            try
                optim_results[irep] = optimize(
                    vars -> compute_error(vars[1], vars[2], field_data, df_unbent, type, kwargs...),
                    [elastic_modulus[1], shear_modulus[1]],  # lower bounds
                    [elastic_modulus[2], shear_modulus[2]],  # upper bounds
                    [start_values_elastic[irep], start_values_shear[irep]],  # initial values
                    Fminbox(LBFGS()),
                    Optim.Options(rel_tol = tol)
                )
            catch
                @warn "Multivariate optimization failed for repetition $irep"
                optim_results[irep] = nothing
            end
        end
    end

    # Get the estimated values
    est_values = [(isnothing(opt) ? (NaN, NaN) : Optim.minimizer(opt)) for opt in optim_results]

    # Identification of the repetition with the minimum quadratic error
    criteria = [Optim.minimum(optim_results[i]) for i in valid_results]
    ind_min_crit = valid_results[argmin(criteria)]

    params = NamedTuple()
    if type == "bending"
        params = merge(params, (elastic_modulus = est_values[ind_min_crit],))
        params = merge(params, (shear_modulus = y,))
    else
        params = merge(params, (elastic_modulus = y,))
        params = merge(params, (shear_modulus = est_values[ind_min_crit],))
    end

    init_values = DataFrame(
        elastic_modulus = start_values_elastic,
        shear_modulus = start_values_shear
    )
end


"""
    distance_weight_sine(x, dF=0.1)

    Computes the distance of application of the right/left weights using a sine function along the beam.

# Arguments

- `x`: Vector of x coordinates of the segments.
- `dF`: Amplitude of the function. Default is 0.1.

# Returns

A vector of the same length as `x` with the distance of application of the right/left weights.

# Examples

```julia
x = [0.0, 1.0, 2.0, 3.0]
distance_weight_sine(x)
```
"""
function distance_weight_sine(x,dF = 0.1)
    return sin.(x ./ x[end] .* π) .* dF
end


"""
    compute_error(x, y, field_data, unbent_data, type="all"; kwargs...)

Compute the simulation error using field data, unbent field data, and bending parameters.
Mainly used by `optimize_bend()`.

# Arguments
- `x`: First parameter (meaning depends on `type`, see Details)
- `y`: Second parameter (meaning depends on `type`, see Details)
- `field_data`: Dictionary of DataFrames with x, y and z coordinates of the points
- `unbent_data`: Dictionary of outputs from `unbend(field_data)` + `distance_weight_sine()`
- `type`: Type of optimization ("bending", "torsion" or "all")
- `kwargs...`: Additional parameters to pass to `bend()`

# Details
Parameters `x` and `y` depend on the optimization type:
- For `type == "bending"`: `x` is elasticity modulus, `y` is shear modulus
- For `type == "torsion"`: `x` is shear modulus, `y` is elasticity modulus
- For `type == "all"`: `x` is a vector with [elasticity_modulus, shear_modulus]

# Returns
The quadratic error of simulation:
- For `type == "bending"`: error in z direction
- For `type == "torsion"`: sum of errors in x and y directions
- For `type == "all"`: sum of errors in x, y and z directions
"""
function compute_error(x, y, field_data, unbent_data, type="all"; kwargs...)
    # Parameter assignment based on optimization type
    if type == "bending"
        elastic_modulus = x
        shear_modulus = y
    elseif type == "torsion"
        elastic_modulus = y
        shear_modulus = x
    else
        elastic_modulus = x[1]
        shear_modulus = x[2]
    end

    # Check that field_data and unbent_data have matching keys
    if keys(field_data) != keys(unbent_data)
        error("Dictionaries field_data and unbent_data do not match")
    end

    # Apply bend() to each item in unbent_data
    df_bent = Dict(
        name => bend(data;
            elastic_modulus=elastic_modulus,
            shear_modulus=shear_modulus,
            kwargs...
        ) for (name, data) in unbent_data
    )

    # Combine all DataFrames
    df_bent_all = vcat(values(df_bent)...)
    field_data_all = vcat(values(field_data)...)

    # Compute quadratic errors (in m)
    npoints = nrow(field_data_all)

    ez = sqrt(sum((field_data_all.z .- df_bent_all.z).^2) / npoints)

    if type == "bending"
        return ez
    end

    ex = sqrt(sum((field_data_all.x .- df_bent_all.x).^2) / npoints)
    ey = sqrt(sum((field_data_all.y .- df_bent_all.y).^2) / npoints)

    if type == "torsion"
        return ex + ey
    end

    if type == "all"
        return ex + ey + ez
    end
end