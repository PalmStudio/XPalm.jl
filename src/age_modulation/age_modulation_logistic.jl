function age_modulation_logistic(age, inflexion_age, min_value, max_value, k)
    # Computes a logistic function of age starting at min_value and ending at max_value
    # The inflexion point is at inflexion_age
    # k is the slope of the logistic function
    # age is the age of the palm in days
    # min_value and max_value are in m2
    # inflexion_age is in days
    # k is in 1/day

    # max_value / (1 + exp(k * (inflexion_age - age))) + min_value
    return min_value + (max_value - min_value) / (1 + exp(-k * (age - inflexion_age)))
end

