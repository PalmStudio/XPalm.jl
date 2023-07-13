"""
age_modulation_logistic(age, inflexion_age, min_value, max_value, k)

Value that depends on the plant age with a logsitic pattern. Computes a logistic function of age starting at min_value and ending at max_value

# Arguments

- `age`: the current age of the plant (in days)
- `inflexion_age`: age ath wich the slope is maximal (inflexion point)
- `min_value`: the starting value 
- `max_value`: the maximum value (treshold)
- `k`: slope at the inflexion point


# Examples 

```jldoctest
>julia age_modulation_logistic(2, 3, 0, 10, 1) 
2.6894142136999513
```
"""

function age_modulation_logistic(age, inflexion_age, min_value, max_value, k)
    return min_value + (max_value - min_value) / (1 + exp(-k * (age - inflexion_age)))
end

