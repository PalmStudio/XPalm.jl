"""
    add_section_geometry!(
        node, internode_width, internode_height, internode_phyllotaxy, stem_bending, 
        refmesh_cylinder, position_section=Ref(Meshes.Point(0.0, 0.0, 0.0)), angles=[0.0, 0.0, 0.0],
        type::String,
    )

Create the petiole/rachis sections geometry based on their dimensions.

# Arguments

- `node`: the MTG node of the petiole/rachis
- `refmesh_cylinder`: the reference mesh used for a cylinder (`PlantGeom.RefMesh`)
- `internode_width`: the width of the internode on the stipe (m)
- `internode_height`: the height of the internode on the stipe (m)
- `internode_phyllotaxy`: the phyllotaxy of the internode on the stipe (°)
- `stem_bending`: the bending of the stipe (°)
- `type::String`: the type of the section (`"PetioleSegment"` or `"RachisSegment"`)
- `position_section=Ref(Meshes.Point(0.0, 0.0, 0.0))`: the position of the section relative to the first one.
"""
function add_section_geometry!(
    node, refmesh_cylinder, internode_width=0.0u"m", internode_height=0.0u"m", internode_phyllotaxy=0.0u"°", stem_bending=0.0u"°",
    type=nothing, position_section=Ref(Meshes.Point(0.0, 0.0, 0.0))
)
    # Check units and convert to meters and degrees:
    internode_width = @check_unit internode_width u"m"
    internode_height = @check_unit internode_height u"m"
    internode_phyllotaxy = @check_unit internode_phyllotaxy u"°"
    stem_bending = @check_unit stem_bending u"°"

    # If type is not provided, we use the symbol of the first child node to filter:
    type = type === nothing ? symbol(node[1]) : type
    # Note: we filter by node type because all nodes may already exist on the MTG, but here we only want to add the geometry to the given section.
    traverse!(node, symbol=type) do node_section
        elevation = node_section.zenithal_angle_global # Elevation (i.e. zenithal angle, in degrees)
        azimuth = node_section.azimuthal_angle_global # Azimuth (in degrees)
        torsion = node_section.torsion_angle_global # Torsion (in degrees)

        # Rotation matrix for the section
        rot = RotYZX(-deg2rad(elevation), deg2rad(azimuth), deg2rad(torsion))

        # The cylinder by default is oriented along Z, so we rotate it to align with X first
        base_orientation = Rotations.RotY(π / 2)

        mesh_transformation =
            Meshes.Scale(ustrip(node_section.height) / 2.0, ustrip(node_section.width) / 2.0, ustrip(node_section.length)) →
            Meshes.Rotate(base_orientation) →  # Orient cylinder along X first
            Meshes.Rotate(rot) →
            Meshes.Translate(Meshes.to(position_section[])...) →
            # Positioning along the stem:
            Meshes.Translate(internode_width, zero(internode_width), internode_height) →
            Meshes.Rotate(RotZ(deg2rad(internode_phyllotaxy))) →
            Meshes.Rotate(RotY(deg2rad(stem_bending)))

        node_section.geometry = PlantGeom.Geometry(ref_mesh=refmesh_cylinder, transformation=mesh_transformation)

        # Update position using the rotation matrix directly
        # Create direction vector along X axis (rachis direction)
        direction = Meshes.Vec(ustrip(node_section.length), 0.0, 0.0)

        # Apply rotation to this direction
        rotated_direction = rot * direction


        node_section.position_section = position_section[]
        node_section.normal_section = rotated_direction

        # Update position
        position_section[] += rotated_direction
    end

    return nothing
end
