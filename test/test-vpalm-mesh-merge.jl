function _mesh_guard_triangle_area(p1, p2, p3)
    ux, uy, uz = p2 .- p1
    vx, vy, vz = p3 .- p1
    cx = uy * vz - uz * vy
    cy = uz * vx - ux * vz
    cz = ux * vy - uy * vx
    return sqrt(cx^2 + cy^2 + cz^2) / 2
end

function _mesh_guard_oriented_cycle(a, b, c)
    return minimum(((a, b, c), (b, c, a), (c, a, b)))
end

function _mesh_guard_point_key(point; digits=10)
    return ntuple(i -> round(Float64(point[i]); digits), 3)
end

function _mesh_guard_oriented_triangles(mesh; digits=10)
    points = GeometryBasics.coordinates(mesh)
    triangles = NTuple{3,NTuple{3,Float64}}[]
    sizehint!(triangles, length(GeometryBasics.faces(mesh)))

    for face in GeometryBasics.faces(mesh)
        a = _mesh_guard_point_key(points[face[1]]; digits)
        b = _mesh_guard_point_key(points[face[2]]; digits)
        c = _mesh_guard_point_key(points[face[3]]; digits)
        push!(triangles, _mesh_guard_oriented_cycle(a, b, c))
    end

    return sort!(triangles)
end

function _mesh_guard_small_mockup_parameters(parameters)
    small = deepcopy(parameters)
    small["nb_leaves_emitted"] = 1
    small["nb_internodes_before_planting"] = 0
    small["nb_leaves_in_sheath"] = 0
    small["rachis_fresh_weight"] = [last(parameters["rachis_fresh_weight"])]
    small["rachis_final_lengths"] = [last(parameters["rachis_final_lengths"])]
    small["petiole_nb_segments"] = 3
    small["rachis_nb_segments"] = 5
    small["biomechanical_model"]["nb_sections"] = 5
    small["leaflets_nb_min"] = 4
    small["leaflets_nb_max"] = 4
    return small
end

@testset "local leaflet mesh contract" begin
    leaflet = MultiScaleTreeGraph.Node(
        MultiScaleTreeGraph.NodeMTG(:/, :Leaflet, 1, 1),
    )
    leaflet.leaflet_segment_lengths = [0.1, 0.2, 0.3]u"m"
    leaflet.leaflet_segment_widths = [0.04, 0.03, 0.02]u"m"
    leaflet.leaflet_segment_angles_deg = [0.0, 0.0, 0.0]u"°"
    leaflet.azimuthal_angle = 0.0u"°"
    leaflet.torsion_angle = 0.0u"°"
    leaflet.lamina_angle = 180.0u"°"

    VPalm.add_leaflet_geometry!(
        leaflet,
        0.0u"m",
        0.0u"m",
        GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0),
        (
            zenithal_angle_global=0.0u"°",
            azimuthal_angle_global=0.0u"°",
            torsion_angle_global=0.0u"°",
        ),
        0.0u"°",
        0.0u"°",
    )

    mesh = leaflet.geometry.ref_mesh.mesh
    points = GeometryBasics.coordinates(mesh)
    faces = GeometryBasics.faces(mesh)
    face_indices = Tuple.(faces)
    areas = [
        _mesh_guard_triangle_area(points[face[1]], points[face[2]], points[face[3]])
        for face in faces
    ]

    @test length(points) == 12
    @test length(faces) == 12
    @test face_indices == [
        (1, 2, 5), (1, 5, 4),
        (2, 3, 6), (2, 6, 5),
        (4, 5, 8), (4, 8, 7),
        (5, 6, 9), (5, 9, 8),
        (7, 8, 11), (7, 11, 10),
        (8, 9, 12), (8, 12, 11),
    ]
    @test all(face -> all(index -> 1 <= index <= length(points), face), face_indices)
    @test all(point -> all(isfinite, point), points)

    @test all(isapprox.(extrema(getindex.(points, 1)), (0.0, 0.6); atol=1.0e-12))
    @test all(isapprox.(extrema(getindex.(points, 2)), (-0.02, 0.02); atol=1.0e-12))
    @test all(isapprox.(extrema(getindex.(points, 3)), (0.0, 0.0); atol=1.0e-12))
    @test sum(areas) ≈ 0.0115 rtol = 1.0e-12
    @test count(<=(1.0e-14), areas) == 2
end

@testset "mockup mesh is conserved across merge scales" begin
    p1 = (0.0, 0.0, 0.0)
    p2 = (1.0, 0.0, 0.0)
    p3 = (0.0, 1.0, 0.0)
    @test _mesh_guard_oriented_cycle(p1, p2, p3) ==
          _mesh_guard_oriented_cycle(p2, p3, p1)
    @test _mesh_guard_oriented_cycle(p1, p2, p3) !=
          _mesh_guard_oriented_cycle(p1, p3, p2)

    parameters = _mesh_guard_small_mockup_parameters(vpalm_parameters)
    merge_scales = (:none, :leaflet, :leaf, :plant)
    triangles = Dict{Symbol,Vector{NTuple{3,NTuple{3,Float64}}}}()

    for merge_scale in merge_scales
        mtg = VPalm.build_mockup(parameters; merge_scale, rng=nothing)
        scene = PlantGeom.prepare_scene(
            mtg;
            compute_area=false,
            compute_barycenter=false,
        )
        triangles[merge_scale] =
            _mesh_guard_oriented_triangles(scene.merged_mesh)
    end

    @test !isempty(triangles[:none])
    @test all(
        triangles[merge_scale] == triangles[:none]
        for merge_scale in merge_scales
    )

    # This is deliberately a mesh-only contract. In particular, it does not
    # freeze the current :plant node topology while that consolidation evolves.
end
