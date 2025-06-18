function build_mockup(parameters; merge_scale=:leaflet)
    @assert merge_scale in (:leaflet, :leaf, :plant)

    mtg = mtg_skeleton(parameters; rng=Random.MersenneTwister(parameters["seed"]))

    # Compute the geometry of the mtg
    # Note: we could do this at the same time than the architecture, but it is separated here for clarity. The downside is that we traverse the mtg twice, but it is pretty cheap.
    refmesh_cylinder = PlantGeom.RefMesh("cylinder", VPalm.cylinder())
    refmesh_snag = PlantGeom.RefMesh("Snag", VPalm.snag(0.05, 1.0, 1.0))
    ref_mesh_plane = PlantGeom.RefMesh("Plane", VPalm.plane())

    add_geometry!(mtg, refmesh_cylinder, refmesh_snag, ref_mesh_plane)

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