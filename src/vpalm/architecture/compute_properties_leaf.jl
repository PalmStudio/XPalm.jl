"""
    compute_properties_leaf!(node, leaf_rank, is_alive, final_length, parameters, rng)

Compute the properties of a leaf node:

- zenithal_insertion_angle: the zenithal insertion angle of the leaf (rad)
- rachis_length: the length of the rachis (m)
- zenithal_cpoint_angle: the zenithal angle at C-point (rad)

# Arguments

- `node`: the leaf node
- `leaf_rank`: the rank of the leaf
- `is_alive`: is the leaf alive or dead (snag)?
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
nb_leaves_alive = floor(Int, mean_and_sd(parameters["nb_leaves_mean"], parameters["nb_leaves_sd"]; rng=rng))
nb_leaves_alive = min(nb_leaves_alive, nb_internodes)
# Plant / Scale 1
plant = Node(NodeMTG("/", "Plant", 1, 1))
# Stem (& Roots) / Scale 2
stem = Node(plant, NodeMTG("+", "Stem", 1, 2))
compute_properties_stem!(stem, parameters, 3.0u"m"; rng=rng)
stem_height = stem[:stem_height]
stem_diameter = stem[:stem_diameter]
# Phytomer / Scale 3
phytomer = Node(stem, NodeMTG("/", "Phytomer", 1, 3))
# Internode & Leaf / Scale 4
internode = Node(phytomer, NodeMTG("/", "Internode", 1, 4))
leaf = Node(internode, NodeMTG("+", "Leaf", 1, 4))
compute_properties_leaf!(leaf, 1, nb_internodes, nb_leaves_alive, parameters, rng)
```
"""
function compute_properties_leaf!(node, leaf_rank, is_alive, final_length, parameters, rng)
    if is_alive
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
    end

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