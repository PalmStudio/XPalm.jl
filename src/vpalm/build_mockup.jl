"""
    build_mockup(parameters; merge_scale=:leaflet)

Construct a mockup of an oil palm plant architecture using the specified parameters.

# Arguments

- `parameters::Dict`: Dictionary containing model parameters for the oil palm plant architecture.
- `merge_scale::Symbol`: (optional) The scale at which to merge geometry.
    - `:node`: Geometry is not merged, each node has its own mesh (finer scale is leaflet segments).
    - `:leaflet` (default): Geometry is merged at the leaflet level.
    - `:leaf`: All geometry for a leaf is merged into a single mesh.
    - `:plant`: All plant geometry is merged into a single mesh.

# Description

The `merge_scale` argument controls how the geometry is structured within the Multiscale Tree Graph (MTG). The resulting mesh is identical in all cases, but its organization differs.

- Using `:leaflet` retains the finest detail, with each leaflet having its own mesh. This is best for analyses like light interception at the organ level.
- Using `:leaf` or `:plant` merges geometry into larger components. A single mesh for the whole plant (`:plant`) is the most performant for rendering, but it prevents querying information for individual organs from the mesh (e.g., which part of the mesh is a given leaflet).

# Returns

- `mtg`: An MTG (Multiscale Tree Graph) representing the oil palm plant architecture, including geometry at the specified merge scale.

# Example

```julia
using XPalm.VPalm
file = joinpath(dirname(dirname(pathof(XPalm))), "test", "references", "vpalm-parameter_file.yml")
parameters = read_parameters(file)
mtg = build_mockup(parameters; merge_scale=:plant)
```
"""
function build_mockup(parameters; merge_scale=:leaflet)
    @assert merge_scale in (:none, :leaflet, :leaf, :plant)

    mtg = mtg_skeleton(parameters; rng=Random.MersenneTwister(parameters["seed"]))

    # Compute the geometry of the mtg
    # Note: we could do this at the same time than the architecture, but it is separated here for clarity. The downside is that we traverse the mtg twice, but it is pretty cheap.
    refmesh_cylinder = PlantGeom.RefMesh("cylinder", VPalm.cylinder())
    refmesh_snag = PlantGeom.RefMesh("Snag", VPalm.snag())
    refmesh_plane = PlantGeom.RefMesh("Plane", VPalm.plane())

    add_geometry!(mtg, refmesh_cylinder, refmesh_snag, refmesh_plane)

    if merge_scale == :leaflet
        # Merge leaflets segments geometry into the leaflets:
        PlantGeom.merge_children_geometry!(mtg; from="LeafletSegment", into="Leaflet", child_link_fun=child_link_fun_no_warning)
    elseif merge_scale == :leaf
        PlantGeom.merge_children_geometry!(mtg; from=["PetioleSegment", "RachisSegment", "LeafletSegment"], into="Leaf", child_link_fun=child_link_fun_no_warning, verbose=false)
        delete_nodes!(mtg, symbol=["Rachis", "Petiole"], child_link_fun=child_link_fun_no_warning)
    elseif merge_scale == :plant
        PlantGeom.merge_children_geometry!(mtg; from=["Stem", "Leaf", "PetioleSegment", "RachisSegment", "LeafletSegment"], into="Plant", child_link_fun=child_link_fun_no_warning, verbose=false)
        delete_nodes!(mtg, symbol=["Rachis", "Petiole"], child_link_fun=child_link_fun_no_warning)
    end
    return mtg
end

child_link_fun_no_warning(x) = new_child_link(x, false)