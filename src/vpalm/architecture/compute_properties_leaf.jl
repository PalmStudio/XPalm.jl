"""
    compute_properties_leaf!(node, leaf_rank, final_length, parameters, rng)

Compute the properties of a leaf node:

- zenithal_insertion_angle: the zenithal insertion angle of the leaf (rad)
- rachis_length: the length of the rachis (m)
- zenithal_cpoint_angle: the zenithal angle at C-point (rad)

# Arguments

- `node`: the leaf node
- `leaf_rank`: the rank of the leaf
- `final_length`: the final length of the leaf (m)
- `parameters`: the parameters of the model
- `rng`: the random number generator

# Returns
The leaf node updated with properties.

# Details

The leaf dimensions are computed based on the dimensions of the stem and the parameters of the model:
- zenithal_insertion_angle: the zenithal insertion angle of the leaf (rad). Uses the `VPalm.leaf_insertion_angle` function.
- rachis_length: the length of the rachis (m). Uses the `rachis_expansion` function.
- zenithal_cpoint_angle: the zenithal angle at C-point (rad). Uses the `c_point_angle` function.

# Examples

```julia
using XPalm.VPalm
using Unitful

file = joinpath(dirname(dirname(pathof(VPalm))), "test", "files", "parameter_file.yml")
parameters = read_parameters(file)
nb_internodes = parameters["nb_leaves_emitted"] + parameters["nb_internodes_before_planting"] # The number of internodes emitted since the seed
nb_leaves_alive = floor(Int, mean_and_sd(parameters["nb_leaves_mean"], parameters["nb_leaves_sd"], rng))
nb_leaves_alive = min(nb_leaves_alive, nb_internodes)
# Plant / Scale 1
plant = Node(NodeMTG(:/, :Plant, 1, 1))
# Stem (& Roots) / Scale 2
stem = Node(plant, NodeMTG(:+, :Stem, 1, 2))
compute_properties_stem!(stem, parameters, 3.0u"m"; rng=rng)
stem_height = stem[:stem_height]
stem_diameter = stem[:stem_diameter]
# Phytomer / Scale 3
phytomer = Node(stem, NodeMTG(:/, :Phytomer, 1, 3))
# Internode & Leaf / Scale 4
internode = Node(phytomer, NodeMTG(:/, :Internode, 1, 4))
leaf = Node(internode, NodeMTG(:+, :Leaf, 1, 4))
compute_properties_leaf!(leaf, 1, nb_internodes, nb_leaves_alive, parameters, rng)
```
"""
function compute_properties_leaf!(node, leaf_rank, final_length, parameters, rng)
    node[:zenithal_insertion_angle] = VPalm.leaf_insertion_angle(
        leaf_rank,
        parameters["leaf_max_angle"],
        parameters["leaf_slope_angle"],
        parameters["leaf_inflection_angle"]
    )
    node[:rachis_length] = rachis_expansion(leaf_rank, final_length)

    node[:zenithal_cpoint_angle] =
        max(
            c_point_angle(leaf_rank, parameters["cpoint_decli_intercept"], parameters["cpoint_decli_slope"], parameters["cpoint_angle_SDP"]; rng=rng),
            node[:zenithal_insertion_angle]
        )
    # RV: I add this new thing were the zenithal cpoint angle cannot be lower than the insertion angle. Note that the angle is relative to the vertical (z)
    # I do that because it would be weird if a leaf was going upward.

    return nothing
end

"""
    rachis_length_from_biomass(rachis_biomass, leaf_length_intercept, leaf_length_slope)

Compute the length of the rachis based on its biomass using a linear relationship.

# Arguments

- `rachis_biomass`: The biomass of the rachis (g).
- `leaf_length_intercept`: The intercept of the linear relationship for leaf length.
- `leaf_length_slope`: The slope of the linear relationship for leaf length.

# Returns

The length of the rachis (m).
"""
function rachis_length_from_biomass(rachis_biomass, leaf_length_intercept, leaf_length_slope)
    return linear(rachis_biomass, leaf_length_intercept, leaf_length_slope)
end

"""
    rachis_length_from_emitted_leaf_number(
        emitted_leaf_number,
        intercept,
        slope;
        juvenile_transition_leaf=nothing,
        juvenile_exponent=nothing,
    )

Compute the final rachis length from the leaf emission sequence. The historical
linear age allometry is used by default. When both juvenile parameters are
provided, a power law is connected exactly to that linear law at the requested
emission index.
"""
function rachis_length_from_emitted_leaf_number(
    emitted_leaf_number,
    intercept,
    slope;
    juvenile_transition_leaf=nothing,
    juvenile_exponent=nothing,
)
    emitted_leaf_number >= 0 || throw(ArgumentError("The emitted leaf number must be non-negative"))
    adult_length = linear(emitted_leaf_number, intercept, slope)
    if isnothing(juvenile_transition_leaf) && isnothing(juvenile_exponent)
        return adult_length
    end
    if isnothing(juvenile_transition_leaf) || isnothing(juvenile_exponent)
        throw(
            ArgumentError(
                "juvenile_transition_leaf and juvenile_exponent must be provided together",
            ),
        )
    end
    juvenile_transition_leaf > 0 || throw(
        ArgumentError("juvenile_transition_leaf must be positive"),
    )
    juvenile_exponent > 0.0 || throw(
        ArgumentError("juvenile_exponent must be positive"),
    )
    emitted_leaf_number >= juvenile_transition_leaf && return adult_length

    adult_length_at_transition = linear(
        juvenile_transition_leaf,
        intercept,
        slope,
    )
    return adult_length_at_transition *
           (emitted_leaf_number / juvenile_transition_leaf)^juvenile_exponent
end

"""
    final_rachis_length(leaf_index, rachis_biomass, parameters)

Return the final rachis length for a dynamic leaf. An age-dependent allometry
is preferred when it is parameterized; the historical fresh-rachis-biomass
allometry remains available for parameter files that do not define it.
"""
function final_rachis_length(leaf_index, rachis_biomass, parameters)
    if haskey(parameters, "rachis_length_age_intercept") &&
       haskey(parameters, "rachis_length_age_slope")
        length_from_age = rachis_length_from_emitted_leaf_number(
            leaf_index,
            parameters["rachis_length_age_intercept"],
            parameters["rachis_length_age_slope"];
            juvenile_transition_leaf=get(
                parameters,
                "rachis_length_juvenile_transition_leaf",
                nothing,
            ),
            juvenile_exponent=get(
                parameters,
                "rachis_length_juvenile_exponent",
                nothing,
            ),
        )
        return haskey(parameters, "rachis_length_age_max") ?
               min(length_from_age, parameters["rachis_length_age_max"]) :
               length_from_age
    end

    return rachis_length_from_biomass(
        rachis_biomass,
        parameters["leaf_length_intercept"],
        parameters["leaf_length_slope"],
    )
end

"""
    rachis_fresh_biomass_for_geometry(rachis_length, fallback_biomass, parameters)

Estimate the fresh rachis biomass needed by VPalm's biomechanical model. When
the age allometry determines length, invert the historical length/fresh-mass
relationship so that XPalm's total dry leaf biomass is not passed as fresh
rachis biomass. Otherwise retain the supplied biomass for compatibility.
"""
function rachis_fresh_biomass_for_geometry(rachis_length, fallback_biomass, parameters)
    uses_age_allometry =
        haskey(parameters, "rachis_length_age_intercept") &&
        haskey(parameters, "rachis_length_age_slope")
    if uses_age_allometry &&
       haskey(parameters, "leaf_length_intercept") &&
       haskey(parameters, "leaf_length_slope")
        biomass = (rachis_length - parameters["leaf_length_intercept"]) /
                  parameters["leaf_length_slope"]
        return max(0.0u"kg", uconvert(u"kg", biomass))
    end

    return fallback_biomass
end

"""
    fresh_biomass_from_dry_mass(dry_mass_g, dry_matter_fraction)

Convert an XPalm structural dry mass in grams to the fresh mass expected by
VPalm's biomechanical model. The dry-matter fraction is organ-specific and must
be expressed on a fresh-mass basis (`dry / fresh`).

This helper remains available for standalone VPalm calculations. The dynamic
XPalm coupling uses `LeafFreshBiomass` so simulated non-structural reserves are
also included in the gravitational mass.
"""
function fresh_biomass_from_dry_mass(dry_mass_g, dry_matter_fraction)
    0.0 < dry_matter_fraction <= 1.0 || throw(
        ArgumentError("dry_matter_fraction must be in (0, 1]"),
    )
    return uconvert(
        u"kg",
        max(0.0, dry_mass_g) * u"g" / dry_matter_fraction,
    )
end

"""
    coupled_leaf_dimension_scale(
        rachis_dry_mass_g,
        final_potential_area,
        lma_min,
        leaflets_biomass_contribution,
        rachis_biomass_contribution,
        exponent,
    )

Return the linear expansion of a coupled VPalm leaf from the structural rachis
dry mass actually acquired in XPalm. Potential rachis mass is derived from the
leaf's potential one-sided leaflet area and XPalm's dry-mass partitioning.

With the default exponent `0.5`, linear dimensions scale with the square root
of acquired biomass, so projected leaflet area scales approximately linearly
with biomass. The result is capped at one: allocation can make a leaf smaller
than its age-dependent VPalm reference, but cannot make it exceed that
potential geometry.
"""
function coupled_leaf_dimension_scale(
    rachis_dry_mass_g,
    final_potential_area,
    lma_min,
    leaflets_biomass_contribution,
    rachis_biomass_contribution,
    exponent,
)
    final_potential_area > 0.0 || return 0.0
    lma_min > 0.0 || throw(ArgumentError("lma_min must be positive"))
    leaflets_biomass_contribution > 0.0 || throw(
        ArgumentError("leaflets_biomass_contribution must be positive"),
    )
    rachis_biomass_contribution > 0.0 || throw(
        ArgumentError("rachis_biomass_contribution must be positive"),
    )
    exponent > 0.0 || throw(ArgumentError("dimension growth exponent must be positive"))

    potential_total_dry_mass =
        final_potential_area * lma_min / leaflets_biomass_contribution
    potential_rachis_dry_mass =
        potential_total_dry_mass * rachis_biomass_contribution
    biomass_fraction = clamp(
        max(0.0, rachis_dry_mass_g) / potential_rachis_dry_mass,
        0.0,
        1.0,
    )
    return biomass_fraction^exponent
end

first_visible_leaf_rank(parameters) = 1 - parameters["nb_leaves_in_sheath"]
is_visible_leaf_rank(rank, parameters) = rank >= first_visible_leaf_rank(parameters)

"""
    rachis_expansion(leaf_rank, rachis_final_length)

    Simple function to compute the rachis expansion (using an expansion factor)
        based on the leaf rank.

    # Arguments

    - `leaf_rank`: The rank of the leaf.
    - `rachis_final_length`: The final length of the rachis.
"""
function rachis_expansion(leaf_rank, rachis_final_length)
    expansion_factor = leaf_rank < 2 ? 0.7 : 1.0
    return rachis_final_length * expansion_factor
end
