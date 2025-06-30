"""
    compute_properties_stem!(node, parameters, length_reference_leaf; rng=MersenneTwister(1234))

Compute the properties of the stem node.

# Arguments
- `node`: the stem node
- `parameters`: the parameters of the Vpalm model
- `length_reference_leaf`: the length of the reference leaf (usually, rank 17)
- `rng=MersenneTwister(1234)`: the random number generator

# Returns
The stem node updated with properties.

# Details
The stem dimensions are computed based on the parameters of the model:
- stem_bending: the bending of the stem. Uses the `VPalm.stem_bending` function.
- stem_height: the height of the stem. Uses the `VPalm.stem_height` function.
- stem_diameter: the diameter of the stem. Uses the `VPalm.stem_diameter` function.

# Examples

```julia
using XPalm.VPalm
using Unitful

file = joinpath(dirname(dirname(pathof(VPalm))), "test", "references", "vpalm-parameter_file.yml")
parameters = read_parameters(file)
nb_internodes = parameters["nb_leaves_emitted"] + parameters["nb_internodes_before_planting"] # The number of internodes emitted since the seed
nb_leaves_alive = floor(Int, mean_and_sd(parameters["nb_leaves_mean"], parameters["nb_leaves_sd"]; rng=rng))
nb_leaves_alive = min(nb_leaves_alive, nb_internodes)
# Plant / Scale 1
plant = Node(NodeMTG("/", "Plant", 1, 1))
# Stem (& Roots) / Scale 2
stem = Node(plant, NodeMTG("+", "Stem", 1, 2))
compute_properties_stem!(stem, parameters, 3.0u"m"; rng=rng)
```
"""
function compute_properties_stem!(node, parameters, length_reference_leaf; rng=Random.MersenneTwister(1234))
    node[:stem_bending] = VPalm.stem_bending(
        parameters["stem_bending_mean"],
        parameters["stem_bending_sd"]; rng=rng
    )
    node[:stem_height] = VPalm.stem_height(
        parameters["nb_leaves_emitted"],
        parameters["initial_stem_height"],
        parameters["stem_height_coefficient"],
        parameters["internode_length_at_maturity"],
        parameters["stem_growth_start"],
        parameters["stem_height_variation"]; rng=rng
    )
    node[:stem_diameter] = VPalm.stem_diameter(
        length_reference_leaf,
        parameters["stem_diameter_max"],
        parameters["stem_diameter_slope"],
        parameters["stem_diameter_inflection"],
        parameters["stem_diameter_residual"],
        parameters["stem_diameter_snag"]; rng=rng
    )
    return nothing
end