"""
    add_leaflet_geometry!(
        leaflet_node,
        internode_radius,
        internode_height,
        rachis_position,
        rachis_orientation,
        rachis_rotation,
        stem_bending,
    )

Create one Java-style extruded leaflet geometry from the stored segment profile.

# Arguments
- `leaflet_node`: The MTG node of the leaflet
- `internode_radius`: Radius of the internode (used for positioning)
- `internode_height`: Height of the internode (used for positioning)
- `rachis_position`: Position of the rachis section where the leaflet is attached
- `rachis_orientation`: Orientation angles [zenithal, azimuthal, torsion] of the rachis section
- `rachis_rotation`: Rotation of the rachis due to phyllotaxy (degrees)
- `stem_bending`: Bending of the stem (degrees)

# Returns
- Nothing (the geometry is added directly to the leaflet node)
"""
function _leaflet_local_extrusion(leaflet_node)
    h_angle = deg2rad(leaflet_node["azimuthal_angle"])
    torsion = deg2rad(leaflet_node["torsion_angle"]) + π / 2.0
    segment_lengths = leaflet_node[:leaflet_segment_lengths]
    segment_widths = leaflet_node[:leaflet_segment_widths]
    segment_angles_deg = leaflet_node[:leaflet_segment_angles_deg]
    n_segments = length(segment_lengths)

    path = Vector{GeometryBasics.Point{3,Float64}}(undef, n_segments + 1)
    path_normals = Vector{GeometryBasics.Vec{3,Float64}}(undef, n_segments + 1)
    widths = Vector{Float64}(undef, n_segments + 1)
    heights = Vector{Float64}(undef, n_segments + 1)
    path[1] = _point3(0.0, 0.0, 0.0)
    position = path[1]

    for (slot, i) in enumerate(eachindex(segment_lengths))
        segment_angle = deg2rad(segment_angles_deg[i])
        rot = RotZYX(h_angle, segment_angle, torsion)
        tangent = rot * _vec3(1.0, 0.0, 0.0)
        cross_blade = rot * _vec3(0.0, 0.0, 1.0)
        segment_length = _coord(segment_lengths[i])
        segment_width = _coord(segment_widths[i])

        path_normals[slot] = cross_blade
        widths[slot] = segment_width
        heights[slot] = segment_width

        step = tangent * segment_length
        position = _point3(
            position[1] + step[1],
            position[2] + step[2],
            position[3] + step[3],
        )
        path[slot + 1] = position
    end

    last_segment_angle = deg2rad(segment_angles_deg[lastindex(segment_lengths)])
    last_rot = RotZYX(h_angle, last_segment_angle, torsion)
    path_normals[end] = last_rot * _vec3(0.0, 0.0, 1.0)
    widths[end] = 0.0
    heights[end] = 0.0

    return path, widths, heights, path_normals
end

function add_leaflet_geometry!(
    leaflet_node,
    internode_radius,
    internode_height,
    rachis_position,
    rachis_orientation,
    rachis_rotation,
    stem_bending,
)
    section = PlantGeom.leaflet_midrib_profile(
        ;
        lamina_angle_deg=_coord(leaflet_node["lamina_angle"]),
        scale=0.5,
    )
    path, widths, heights, path_normals = _leaflet_local_extrusion(leaflet_node)

    leaflet_refmesh = PlantGeom.extrude_profile_refmesh(
        "Leaflet$(node_id(leaflet_node))",
        section,
        path;
        widths=widths,
        heights=heights,
        path_normals=path_normals,
        torsion=true,
        close_section=false,
        cap_ends=false,
    )

    mesh_transformation =
        _rotate(RotY(deg2rad(stem_bending))) ∘
        _rotate(RotZ(deg2rad(rachis_rotation))) ∘
        _translate(internode_radius, zero(internode_radius), internode_height) ∘
        _translate(rachis_position) ∘
        _rotate(
            RotZYX(
                deg2rad(rachis_orientation.azimuthal_angle_global),
                -deg2rad(rachis_orientation.zenithal_angle_global),
                deg2rad(rachis_orientation.torsion_angle_global),
            )
        )

    leaflet_node.geometry = PlantGeom.Geometry(ref_mesh=leaflet_refmesh, transformation=mesh_transformation)

    return nothing
end
