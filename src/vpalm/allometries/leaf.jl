"""
    leaf_insertion_angle(rank, leaf_max_angle=90, leaf_slope_angle=0.05, leaf_inflection_angle=40)

Compute the insertion angle of the leaf on the internode.

Note: The insertion angle is computed using a logistic function.

# Arguments

- `rank`: The rank of the leaf.
- `leaf_max_angle`: The maximum angle of the leaf.
- `leaf_slope_angle`: The slope of the logistic function.
- `leaf_inflection_angle`: The inflection point of the logistic function.
"""
function leaf_insertion_angle(rank, leaf_max_angle=90.0, leaf_slope_angle=0.05, leaf_inflection_angle=40.0)
    return logistic(rank, leaf_max_angle, leaf_slope_angle, leaf_inflection_angle)
end