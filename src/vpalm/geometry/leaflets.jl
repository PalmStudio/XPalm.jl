"""
    add_leaflet_geometry!(
        leaflet_node,
        internode_width,
        internode_height,
        rachis_position,
        rachis_orientation,
        rachis_rotation,
        stem_bending,
    )

Create one Java-style extruded leaflet geometry from the stored segment profile.

# Arguments
- `leaflet_node`: The MTG node of the leaflet
- `internode_width`: Width of the internode (used for positioning)
- `internode_height`: Height of the internode (used for positioning)
- `rachis_position`: Position of the rachis section where the leaflet is attached
- `rachis_orientation`: Orientation angles [zenithal, azimuthal, torsion] of the rachis section
- `rachis_rotation`: Rotation of the rachis due to phyllotaxy (degrees)
- `stem_bending`: Bending of the stem (degrees)

# Returns
- Nothing (the geometry is added directly to the leaflet node)
"""
_segment_width(segment) = segment isa NamedTuple ? segment.width : segment["width"]
_segment_length(segment) = segment isa NamedTuple ? segment.length : segment["length"]
_segment_angle_deg(segment) = segment isa NamedTuple ? segment.zenithal_angle : segment["zenithal_angle"]

function _leaflet_segments(leaflet_node)
    [(
        width=leaflet_node[:leaflet_segment_widths][i],
        length=leaflet_node[:leaflet_segment_lengths][i],
        zenithal_angle=leaflet_node[:leaflet_segment_angles_deg][i],
    ) for i in eachindex(leaflet_node[:leaflet_segment_lengths])]
end

function _leaflet_local_extrusion(leaflet_node)
    h_angle = deg2rad(leaflet_node["azimuthal_angle"])
    torsion = deg2rad(leaflet_node["torsion_angle"]) + π / 2.0
    segments = _leaflet_segments(leaflet_node)

    path = GeometryBasics.Point{3,Float64}[_point3(0.0, 0.0, 0.0)]
    path_normals = GeometryBasics.Vec{3,Float64}[]
    widths = Float64[]
    heights = Float64[]
    position = path[1]

    for segment in segments
        segment_angle = deg2rad(_segment_angle_deg(segment))
        rot = RotZYX(h_angle, segment_angle, torsion)
        tangent = rot * _vec3(1.0, 0.0, 0.0)
        cross_blade = rot * _vec3(0.0, 0.0, 1.0)
        segment_length = _coord(_segment_length(segment))
        segment_width = _coord(_segment_width(segment))

        push!(path_normals, cross_blade)
        push!(widths, segment_width)
        push!(heights, segment_width)

        step = tangent * segment_length
        position = _point3(
            position[1] + step[1],
            position[2] + step[2],
            position[3] + step[3],
        )
        push!(path, position)
    end

    last_segment_angle = deg2rad(_segment_angle_deg(last(segments)))
    last_rot = RotZYX(h_angle, last_segment_angle, torsion)
    push!(path_normals, last_rot * _vec3(0.0, 0.0, 1.0))
    push!(widths, 0.0)
    push!(heights, 0.0)

    return path, widths, heights, path_normals
end

function add_leaflet_geometry!(
    leaflet_node,
    internode_width,
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
        _translate(internode_width, zero(internode_width), internode_height) ∘
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
