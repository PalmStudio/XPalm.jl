"""
    add_leaflet_geometry!(
        leaflet_node, 
        rachis_position, 
        rachis_orientation, 
        rachis_rotation, 
        stem_bending, 
        refmesh_plane
    )

Create the leaflet geometry based on its segments.

# Arguments
- `leaflet_node`: The MTG node of the leaflet
- `rachis_position`: Position of the rachis section where the leaflet is attached
- `rachis_orientation`: Orientation angles [zenithal, azimuthal, torsion] of the rachis section
- `rachis_rotation`: Rotation of the rachis due to phyllotaxy (radians)
- `stem_bending`: Bending of the stem (radians)
- `refmesh_plane`: Reference mesh used for the planar leaflet segments

# Returns
- Nothing (the geometry is added directly to the leaflet node and its segments)
"""
function add_leaflet_geometry!(
    leaflet_node,
    internode_width,
    internode_height,
    rachis_position,
    rachis_orientation,
    rachis_rotation,
    stem_bending,
    refmesh_plane
)
    # Extract basic leaflet properties
    side = leaflet_node["side"]
    h_angle = deg2rad(leaflet_node["azimuthal_angle"])   # Horizontal angle (insertion angle in Z)  
    v_angle = deg2rad(leaflet_node["zenithal_angle"])    # Vertical angle (insertion angle in X)
    torsion = deg2rad(leaflet_node["torsion_angle"]) + π / 2.0 # Twist around leaflet's axis
    lamina_angle = deg2rad(leaflet_node["lamina_angle"]) # V-shape of the leaflet

    # Create reference point for the leaflet base
    leaflet_base_position = rachis_position

    # Accumulate position and angle for segments
    position_section = Ref(Meshes.Point(0.0, 0.0, 0.0))

    # Calculate the orientation for the full leaflet
    # 1. Apply leaflet's insertion angles (horizontal and vertical)
    # 2. Apply torsion around leaflet's own axis
    # 3. Apply rachis orientation (inherit from parent)
    rot_rachis =
        Meshes.Rotate(
            RotYZX(
                -deg2rad(rachis_orientation.zenithal_angle_global),
                deg2rad(rachis_orientation.azimuthal_angle_global),
                deg2rad(rachis_orientation.torsion_angle_global)
            )
        )

    # Process each leaflet segment
    traverse!(leaflet_node, symbol="LeafletSegment") do segment
        # Get segment properties
        leaflet_segment_width = segment["width"]
        leaflet_segment_length = segment["length"]
        # Apply stiffness angle if available (segment bending due to weight)
        # Calculate the absolute angle of this segment by adding the stiffness angle to previous segment angle
        # segment_angle += side * deg2rad(segment["zenithal_angle"])
        segment_angle = deg2rad(segment["zenithal_angle"])
        # segment_angle += deg2rad(15.0)
        # Rotation matrix for the section
        rot = RotZYX(h_angle, segment_angle, torsion)
        # Calculate transformation for this segment
        # !Based on ElaeisArchiTree.java line 246-254, the leaflet shape is a V-shaped plane, but not working here!
        mesh_transformation =
        # Scale to correct dimensions
        # Meshes.Scale(ustrip(leaflet_segment_width), ustrip(leaflet_segment_width) * sin(lamina_angle / 2), ustrip(leaflet_segment_length)) →
            Meshes.Scale(ustrip(leaflet_segment_length), 1e-6, ustrip(leaflet_segment_width)) →
            # Note: we use 1e-6 for the leaflet thickness because it's a plane so it's not really used, but we still need a non-zero value for scaling
            Meshes.Rotate(rot) →
            # Apply position offset from previous segments
            Meshes.Translate(Meshes.to(position_section[])...) →
            # Apply rachis orientation
            rot_rachis →
            # Translate to rachis position
            Meshes.Translate(Meshes.to(leaflet_base_position)...) →
            # Positioning along the stem:
            Meshes.Translate(internode_width, zero(internode_width), internode_height) →
            Meshes.Rotate(RotZ(deg2rad(rachis_rotation))) →
            Meshes.Rotate(RotY(deg2rad(stem_bending)))

        # Assign geometry to the segment
        segment.geometry = PlantGeom.Geometry(ref_mesh=refmesh_plane, transformation=mesh_transformation)

        # Update position using the rotation matrix directly
        # Create direction vector along X axis (rachis direction)
        direction = Meshes.Vec(ustrip(leaflet_segment_length), 0.0, 0.0)

        # Apply rotation to this direction
        rotated_direction = rot * direction
        # Update position
        position_section[] += rotated_direction
    end

    return nothing
end
