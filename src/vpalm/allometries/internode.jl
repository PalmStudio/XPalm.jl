"""
    internode_diameter(internode_index, nb_internodes, stem_diameter, stem_base_shrinkage, stem_top_shrinkage, leaves_in_sheath)

Computes the diameter of an internode at a given rank.

# Arguments
- `internode_index`: The index of the internode.
- `nb_internodes`: The total number of internodes.
- `stem_diameter`: The diameter of the stem at the base.
- `stem_base_shrinkage`: The shrinkage coefficient at the stem base.
- `stem_top_shrinkage`: The shrinkage coefficient at the stem top.
- `leaves_in_sheath`: The number of leaves in the sheath.

# Returns
The diameter of the internode (m).

# Details
A shrinking function is applied to the stem base and top to compute the diameter of the internode.
"""
function internode_diameter(internode_index, nb_internodes, stem_diameter, stem_base_shrinkage, stem_top_shrinkage, leaves_in_sheath)
    # Shrink trunk base
    diameter = stem_diameter * (1 - exp(-stem_base_shrinkage * internode_index))
    # Shrink trunk top
    frond_rank = nb_internodes - internode_index - leaves_in_sheath
    reduction_factor = max(0, min(1, 1 - exp(-stem_top_shrinkage * frond_rank)))
    return diameter * reduction_factor
end


"""
    Internode length model

Computes the length of an internode at a given rank.

# Arguments
- `i`/ `internode_index`: The index of the internode.
- `Nbl` / `nb_internodes`: The total number of internodes == number of leaves emitted since planting.
- `sh` / `stem_height`: The height of the stem.
- `R` / `internode_rank_no_expansion`: The rank of the internode that will not expand.
- `N` / `nb_internodes_before_planting`: The number of internodes before planting.
- `l_0` / `internode_min_height`: The minimal length of the internode.

# Returns
The length of the internode (m).

# Details
The internode length is computed using a quadratic function.
The objective is to have a internodes that are short and growing for the first emitted leaves (before `nb_internodes_before_planting`),
and then getting to a stable "constant" height, and at the end for the youngest leaves, having nodes currently growing (smaller).

The internode length is computed as follows :
  Internode length
    ^
l   |      _____________________
    |    /|                     |\
    |   / |                     | \
l_0 |  /  |                     |  \
    |-|---|---------------------|---|----> Internode number
      1   N                   N +   N + Nbl
       						  Nbl -
                              R
where :
    - l_0 is `internode_min_height` (m), the minimum height of the internode.
    - l is `internode_heigth_final` (m), the maximum height of the internode.`
    - N is `nb_internodes_before_planting`, the number of internodes before planting.
    - R is `internode_rank_no_expansion`, the number of internodes not in expansion.
    - Nbl is the number of leaves emitted since planting.
with the conditions that :
    - the sum of the areas of the first triangle, the rectangle and the last triangle is equal to `stem_height`.
    - if the equation of the first line is `a * x + b`:
        - `a = (l - l_0) / (N - 1)`
        - `b = l_0 - a`
        - the area of the first triangle is `a * N * (N + 1) / 2 + b * N`
                and after development : `l * N/2 + l_0 * N/2`
    - the area of the rectangle (between N + 1 and N + Nbl - R - 1) is `(Nbl - R - 1) * l`
    - if the equation of the last line is `c * x + d`, then:
        - `c = (l_0 - l) / R`
        - `d = l_0 - c * (Nbl + N)`
        - the area of the last triangle is `(R + 1) * (c * (2*N + 2*Nbl - R) / 2 + d)`
                and after development : `l * ((R + 1)/ 2) + l_0 * (-(R + 1) / 2 + R + 1)`
reminder:
    - the sum of integers from m to n is `n * (n + 1) / 2 - m * (m - 1) / 2`
    - the sum of cx + d from m to n is `c * (n * (n + 1) / 2 - m * (m - 1) / 2) + d * (n - m + 1)`
                                    or `(n - m + 1) * (c * (n + m) / 2 + d)`
"""
function internode_length(i, Nbl, sh, R, N, l_0)
    # Computation of the internode final / max length so that the sum of all the internodes length is equal to the stem height
    l = (sh - l_0 * (N / 2 - (R + 1) / 2 + R + 1)) / (N / 2 + Nbl - R - 1 + (R + 1) / 2)

    # Coefficients for the computation of internode length for the first N internodes
    a = (l - l_0) / (N - 1)
    b = l_0 - a

    # Coefficients for the computation of internode length for the last R internodes
    c = (l_0 - l) / R
    d = l_0 - (Nbl + N) * c

    if i <= N
        internode_l = a * i + b
    elseif i < (N + Nbl - R)
        internode_l = l
    else
        internode_l = c * i + d
    end

    return internode_l
end

"""
    phyllotactic_angle(phyllotactic_angle_mean, phyllotactic_angle_sd; rng=Random.MersenneTwister(1234))

Computes the phyllotactic angle (°) using an average angle and a standard deviation (random draw from a normal distribution).

# Arguments

- `phyllotactic_angle_mean`: The average phyllotactic angle (°).
- `phyllotactic_angle_sd`: The standard deviation of the phyllotactic angle (°).

# Optional arguments

- `rng`: The random number generator.
"""
function phyllotactic_angle(phyllotactic_angle_mean, phyllotactic_angle_sd; rng=Random.MersenneTwister(1234))
    return mean_and_sd(phyllotactic_angle_mean, phyllotactic_angle_sd; rng=rng)
end
