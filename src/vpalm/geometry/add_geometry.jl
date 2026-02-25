"""
    add_geometry!(
        mtg, refmesh_cylinder, refmesh_snag, refmesh_plane;
        snag_width=0.20u"m", # see defaultOrthotropyAttribute in the trunk in the java implementation
        snag_height=0.15u"m",
        snag_length=3.0u"m",
    )

Adds geometry to the MTG (Multiscale Tree Graph) for the oil palm plant architecture, i.e. compute the meshes.
"""
_coord(x) = Float64(ustrip(x))
_point3(x, y, z) = GeometryBasics.Point{3,Float64}(_coord(x), _coord(y), _coord(z))
_vec3(x, y, z) = GeometryBasics.Vec{3,Float64}(_coord(x), _coord(y), _coord(z))
_translate(x, y, z) = Translation(_coord(x), _coord(y), _coord(z))
_translate(p::GeometryBasics.Point{3,Float64}) = Translation(p[1], p[2], p[3])
_scale(x, y, z) = LinearMap(Diagonal([_coord(x), _coord(y), _coord(z)]))
_rotate(rot) = LinearMap(rot)

function add_geometry!(
    mtg,
    refmesh_cylinder,
    refmesh_snag,
    refmesh_plane;
    snag_width=0.20u"m", # see defaultOrthotropyAttribute in the trunk in the java implementation
    snag_height=0.15u"m",
    snag_length=0.1u"m",
)

    stem_diameter = mtg[1].stem_diameter
    stem_bending = mtg[1].stem_bending
    isnothing(stem_diameter) && (stem_diameter = 0.0u"m")
    isnothing(stem_bending) && (stem_bending = 0.0u"°")
    internode_width = stem_diameter
    snag_insertion_angle = deg2rad(-35.0u"°") # deg2rad(-20.0 - 35.0)
    internode_height = 0.0u"m"
    snag_rotation = 0.0u"°"
    position_section = Ref(_point3(0.0, 0.0, 0.0))

    traverse!(mtg, symbol=[:Internode, :Leaf, :Petiole, :Rachis, :Leaflet]) do node
        if symbol(node) == :Internode
            snag_rotation += node.XEuler
            stem_bending += node.Orthotropy
            internode_width = node.width > 0.0u"m" ? node.width : 0.01u"m"
            mesh_transformation =
                _rotate(RotY(deg2rad(stem_bending))) ∘
                _rotate(RotZ(deg2rad(snag_rotation))) ∘
                _translate(0.0u"m", 0.0u"m", internode_height) ∘
                _scale(internode_width, internode_width, node.length)
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_cylinder, transformation=mesh_transformation)
            internode_height += node.length
        elseif symbol(node) == :Leaf
            if !node.is_alive
                # Dead leaf, we keep the snag only
                mesh_transformation =
                    _rotate(RotY(deg2rad(stem_bending))) ∘
                    _rotate(RotZ(deg2rad(snag_rotation))) ∘
                    _translate(internode_width, 0.0u"m", internode_height) ∘
                    _rotate(RotY(snag_insertion_angle)) ∘
                    _scale(snag_length, snag_width, snag_height)
                node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_snag, transformation=mesh_transformation)
            else
                nothing
            end
        elseif symbol(node) == :Petiole
            # Initialise the position for the petiole to 0.0
            position_section[] = _point3(0.0, 0.0, 0.0)
            add_section_geometry!(node, refmesh_cylinder, internode_width, internode_height, snag_rotation, stem_bending, :PetioleSegment, position_section)
        elseif symbol(node) == :Rachis
            add_section_geometry!(node, refmesh_cylinder, internode_width, internode_height, snag_rotation, stem_bending, :RachisSegment, position_section)
            # Note: we use the position and angles of the last petiole section to initialize the rachis
        elseif symbol(node) == :Leaflet
            # Get the rachis segment node on which the leaflet is attached
            rachis_node = parent(node)

            # Add leaflet geometry with proper position and orientation relative to rachis
            add_leaflet_geometry!(
                node,
                internode_width,
                internode_height,
                rachis_node.position_section,                   # Position of attachment point on rachis
                (; rachis_node.zenithal_angle_global, rachis_node.azimuthal_angle_global, rachis_node.torsion_angle_global),                # Orientation of rachis at attachment point
                snag_rotation,                # Global phyllotaxy rotation
                stem_bending,                 # Global stem bending
                refmesh_plane                 # Reference mesh for leaflet segments
            )
        end
    end
end
