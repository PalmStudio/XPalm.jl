"""
    age_relative_value(age, age_min_value, age_max_value, min_value, max_value)

Value that depends on the plant age.

# Arguments

- `age`: the current age of the plant
- `age_min_value`: the age at which minimum value is reached (ages below this age will hage `min_value`)
- `age_max_value`: the age at which the value is at the maximum value (ages above this age will hage `max_value`)
- `min_value`: the value below or at `age_min_value`
- `max_value`: the value at or above `age_max_value`

# Examples 

```jldoctest
julia> XPalm.age_relative_value(0, 1, 10, 0.1, 0.8)
0.1
```

```jldoctest
julia> XPalm.age_relative_value(5, 1, 10, 0.1, 0.8)
0.4111111111111111
```

```jldoctest
julia> XPalm.age_relative_value(15, 1, 10, 0.1, 0.8)
0.8
```
"""
function age_relative_value(age, age_min_value, age_max_value, min_value, max_value)
    if age > age_max_value
        return max_value
    elseif age < age_min_value
        return min_value
    else
        age_relative = age - age_min_value
        inc = (max_value - min_value) / (age_max_value - age_min_value)
        return min_value + age_relative * inc
    end
end