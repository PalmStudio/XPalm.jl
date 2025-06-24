"""
    compute_properties_internode!(node, index, nb_internodes, rank, stem_height, stem_diameter, parameters, rng)

Computes the mtg properties of an internode.

# Arguments
- `node`: the internode node
- `index`: the index of the internode
- `nb_internodes`: the total number of internodes
- `rank`: the rank of the internode
- `stem_height`: the height of the stem (m)
- `stem_diameter`: the diameter of the stem (m)
- `parameters`: the parameters of the model
- `rng`: the random number generator

# Returns

The internode node updated with properties.

# Details

The internode dimensions are computed based on the dimensions of the stem and the parameters of the model:

- width: width of the internode (m)
- diameter: diameter of the internode (m)
- length: length of the internode (m)
- rank: rank of the internode
- Orthotropy: orthotropy of the internode (set as a constant value)
- XEuler: Euler / phyllotactic angle of the internode (rad)

# Examples

```julia
file = joinpath(dirname(dirname(pathof(VPalm))), "test", "files", "parameter_file.yml")
parameters = read_parameters(file)
nb_internodes = parameters["nb_leaves_emitted"] + parameters["nb_internodes_before_planting"] # The number of internodes emitted since the seed
# Plant / Scale 1
plant = Node(MutableNodeMTG("/", "Plant", 1, 1))
# Stem (& Roots) / Scale 2
stem = Node(plant, MutableNodeMTG("+", "Stem", 1, 2))
compute_properties_stem!(stem, parameters, rng)
stem_height = stem[:stem_height]
stem_diameter = stem[:stem_diameter]
# Phytomer / Scale 3
phytomer = Node(stem, MutableNodeMTG("/", "Phytomer", 1, 3))
# Internode & Leaf / Scale 4
internode = Node(phytomer, MutableNodeMTG("/", "Internode", 1, 4))
compute_properties_internode!(internode, 1, nb_internodes, stem_height, stem_diameter, parameters, rng)
```
"""
function compute_properties_internode!(node, index, nb_internodes, rank, stem_height, stem_diameter, parameters, rng)
    node[:Width] = VPalm.internode_diameter(
        index,
        rank,
        stem_diameter,
        parameters["stem_base_shrinkage"],
        parameters["stem_top_shrinkage"],
    )

    node[:Length] = internode_length(
        index,
        nb_internodes,
        stem_height,
        parameters["internode_rank_no_expansion"],
        parameters["nb_internodes_before_planting"],
        0.001u"m"
        # internode_min_height
    )

    node[:rank] = nb_internodes - index + 1
    node[:Orthotropy] = 0.05u"°"
    node[:XEuler] = VPalm.phyllotactic_angle(
        parameters["phyllotactic_angle_mean"],
        parameters["phyllotactic_angle_sd"]; rng=rng
    )
    return nothing
end