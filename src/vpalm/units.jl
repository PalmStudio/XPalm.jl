"""
    @check_unit(variable, expected_unit, [verbose=true])

Check if a variable has the expected unit type. If no unit is found, assign the expected unit.
If a different unit is found, try to convert to the expected unit.

# Arguments

- `variable`: The variable to check
- `expected_unit`: The expected unit (e.g., u"m")
- `verbose`: Whether to show warnings (default: true)

# Examples

```julia
rachis_length = 10
@check_unit rachis_length u"m"  # Will add u"m" and warn

petiole_length = 10
@check_unit petiole_length u"m" false # Will add u"m" without a warning

mass = 5.0u"g"
@check_unit mass u"kg"   # Will convert g to kg
"""
macro check_unit(variable, expected_unit, verbose=true, param_name=nothing)
    in_var_name = string(variable)
    return quote
        local var_name = isnothing($(esc(param_name))) ? $(in_var_name) : $(esc(param_name))
        local var = $(esc(variable))
        local exp_unit = $(esc(expected_unit))
        local is_verbose = $(esc(verbose))

        # Check if the variable has units
        if unit(var) == NoUnits
            # No units found, assign default
            if is_verbose
                @warn "The `$(var_name)` argument should have units, using $(exp_unit) as default."
            end
            var = var * exp_unit
        else
            # Units found, try to convert
            try
                var = uconvert(exp_unit, var)
            catch e
                error("Cannot convert $(var_name) from $(unit(var)) to $(exp_unit)")
            end
        end

        # Return the variable with proper units
        var
    end
end