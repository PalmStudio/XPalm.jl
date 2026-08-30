"""
    build_mockup(parameters; merge_scale=:leaflet, rng=Random.MersenneTwister(parameters["seed"]))

Construct a mockup of an oil palm plant architecture using the specified parameters.

# Arguments

- `parameters::Dict`: Dictionary containing model parameters for the oil palm plant architecture.
- `merge_scale::Symbol`: (optional) The scale at which to merge geometry.
    - `:none`: Geometry is not merged and remains on its natural owner nodes.
    - `:leaflet` (default): Alias of `:none`, retained for API compatibility.
    - `:leaf`: All geometry for a leaf is merged into a single mesh.
    - `:plant`: All plant geometry is merged into a single mesh.
- `rng`: (optional) A random number generator for stochastic processes. Defaults to a Mersenne Twister seeded with the value in `parameters["seed"]`. If set to `nothing`, randomness is disabled (useful for testing).

# Description

The `merge_scale` argument controls how the geometry is structured within the Multiscale Tree Graph (MTG). The resulting mesh is identical in all cases, but its organization differs.

- Using `:none` or `:leaflet` retains the finest geometry ownership. This is
  best for analyses like light interception at the organ level.
- Using `:leaf` or `:plant` consolidates geometry into larger components while
  retaining every botanical MTG node, identifier and parent/child relation.
  Lower-scale geometry is no longer available individually after consolidation,
  but the corresponding organs remain queryable.

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
function build_mockup(parameters; merge_scale=:leaflet, rng=Random.MersenneTwister(parameters["seed"]))
    @assert merge_scale in (:none, :leaflet, :leaf, :plant)

    mtg = mtg_skeleton(parameters; rng=rng)

    # Compute the geometry of the mtg
    # Note: we could do this at the same time than the architecture, but it is separated here for clarity. The downside is that we traverse the mtg twice, but it is pretty cheap.
    refmesh_cylinder = PlantGeom.RefMesh("cylinder", GeometryBasics.mesh(VPalm.cylinder()))

    add_geometry!(mtg, refmesh_cylinder)

    if merge_scale in (:none, :leaflet)
        # Geometry is already attached to its natural owner nodes.
    elseif merge_scale == :leaf
        source_symbols = (:PetioleSegment, :RachisSegment, :Leaflet)
        PlantGeom.merge_children_geometry!(
            mtg;
            from=source_symbols,
            into=:Leaf,
            delete=:none,
            verbose=false,
        )
        _remove_source_geometry!(mtg, source_symbols)
    elseif merge_scale == :plant
        source_symbols = (
            :Stem,
            :Internode,
            :Leaf,
            :PetioleSegment,
            :RachisSegment,
            :Leaflet,
        )
        PlantGeom.merge_children_geometry!(
            mtg;
            from=source_symbols,
            into=:Plant,
            delete=:none,
            verbose=false,
        )
        _remove_source_geometry!(mtg, source_symbols)
    end
    return mtg
end

function _remove_source_geometry!(mtg, source_symbols)
    traverse!(mtg, symbol=source_symbols) do node
        haskey(node, :geometry) && pop!(node, :geometry)
    end
    return nothing
end
