## Using VPalm to reconstruct a Palm Tree

The package also includes a submodule `VPalm` that is an automaton that builds 3d mockups of palm plants from architectural parameters and allometric equations. It also integrates a biomechanical model to compute the leaf bending and torsion using the biomass of each leaf.

You can run `VPalm` simply by loading the submodule. Here is an example to load `VPalm` default parameters and build a palm tree with a multiscale architecture defined using the [Multiscale Tree Graph format (MTG)](https://github.com/VEZY/MultiScaleTreeGraph.jl).

```julia
using XPalm
using XPalm.VPalm

# Load example parameters
file = joinpath(dirname(dirname(pathof(XPalm))), "test", "references", "vpalm-parameter_file.yml")
parameters = read_parameters(file)

mtg = build_mockup(parameters)

viz(mtg, color = :green)
```

![palm plant](../assets/palm_mockup.png)

!!! details "Code to reproduce this image"
    To reproduce the image above, you can use the following code snippet. It will create a mockup of a palm plant with colored segments based on their type.

    ```julia
    using XPalm
    using XPalm.VPalm
    file = joinpath(dirname(dirname(pathof(XPalm))), "test", "references", "vpalm-parameter_file.yml")
    parameters = read_parameters(file)
    mtg = build_mockup(parameters; merge_scale=:leaflet)
    traverse!(mtg) do node
        if symbol(node) == "Petiole"
            petiole_and_rachis_segments = descendants(node, symbol=["PetioleSegment", "RachisSegment"])
            colormap = cgrad([colorant"peachpuff4", colorant"blanchedalmond"], length(petiole_and_rachis_segments), scale=:log2)
            for (i, seg) in enumerate(petiole_and_rachis_segments)
                seg[:color_type] = colormap[i]
            end
        elseif symbol(node) == "Leaflet"
            node[:color_type] = :mediumseagreen
        elseif symbol(node) == "Leaf" # This will color the snags
            node[:color_type] = :peachpuff4
        end
    end
    f, ax, p = viz(mtg, color=:color_type)
    save("palm_mockup.png", f, size=(800, 600), px_per_unit=3)
    ```

!!! note
    Note that the MTG is built with the following scales: `["Plant", "Stem", "Phytomer", "Internode", "Leaf", "Petiole", "PetioleSegment", "Rachis", "RachisSegment", "Leaflet", "LeafletSegment"]`.
