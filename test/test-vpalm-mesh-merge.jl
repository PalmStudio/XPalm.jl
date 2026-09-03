function _mesh_guard_triangle_area(p1, p2, p3)
    ux, uy, uz = p2 .- p1
    vx, vy, vz = p3 .- p1
    cx = uy * vz - uz * vy
    cy = uz * vx - ux * vz
    cz = ux * vy - uy * vx
    return sqrt(cx^2 + cy^2 + cz^2) / 2
end

function _mesh_guard_area_barycenter(mesh)
    points = GeometryBasics.coordinates(mesh)
    total_area = 0.0
    weighted_centroid = zeros(3)

    for face in GeometryBasics.faces(mesh)
        p1, p2, p3 = points[face[1]], points[face[2]], points[face[3]]
        area = _mesh_guard_triangle_area(p1, p2, p3)
        total_area += area
        for axis in 1:3
            weighted_centroid[axis] +=
                area * (Float64(p1[axis]) + Float64(p2[axis]) + Float64(p3[axis])) / 3
        end
    end

    total_area > 0.0 || error("Cannot compute the barycenter of a zero-area mesh")
    return (
        area=total_area,
        barycenter=ntuple(axis -> weighted_centroid[axis] / total_area, 3),
    )
end

function _mesh_guard_topology(mtg)
    nodes = sort!([mtg; descendants(mtg)]; by=node_id)
    return Tuple(
        begin
            attributes = MultiScaleTreeGraph.node_attributes(node)
            (
                id=node_id(node),
                parent_id=isnothing(parent(node)) ? 0 : node_id(parent(node)),
                link=MultiScaleTreeGraph.link(node),
                symbol=symbol(node),
                index=MultiScaleTreeGraph.index(node),
                scale=MultiScaleTreeGraph.scale(node),
                attributes=Dict(
                    key => deepcopy(attributes[key])
                    for key in keys(attributes) if key != :geometry
                ),
            )
        end
        for node in nodes
    )
end

function _mesh_guard_geometry_owners(mtg)
    nodes = [mtg; descendants(mtg)]
    symbols = (
        :Plant,
        :Stem,
        :Phytomer,
        :Internode,
        :Leaf,
        :Petiole,
        :PetioleSegment,
        :Rachis,
        :RachisSegment,
        :Leaflet,
    )
    return Dict(
        node_symbol => count(
            node -> symbol(node) == node_symbol && PlantGeom.has_geometry(node),
            nodes,
        )
        for node_symbol in symbols
    )
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
    # One living leaf plus one dead-leaf snag exercises both geometry paths.
    small["nb_leaves_emitted"] = 2
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

@testset "leaflet parent-pose transformation contract" begin
    leaflet = MultiScaleTreeGraph.Node(
        MultiScaleTreeGraph.NodeMTG(:/, :Leaflet, 1, 1),
    )
    leaflet.leaflet_segment_lengths = [0.1]u"m"
    leaflet.leaflet_segment_widths = [0.04]u"m"
    leaflet.leaflet_segment_angles_deg = [0.0]u"°"
    leaflet.azimuthal_angle = 0.0u"°"
    leaflet.torsion_angle = 0.0u"°"
    leaflet.lamina_angle = 180.0u"°"
    leaflet.offset = 0.25u"m"

    VPalm.add_leaflet_geometry!(
        leaflet,
        2.0u"m",
        3.0u"m",
        GeometryBasics.Point{3,Float64}(4.0, 5.0, 6.0),
        (
            zenithal_angle_global=90.0u"°",
            azimuthal_angle_global=90.0u"°",
            torsion_angle_global=90.0u"°",
        ),
        90.0u"°",
        90.0u"°",
    )

    transform = leaflet.geometry.transformation
    landmarks = (
        GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0),
        GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0),
        GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0),
        GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.0),
    )
    expected = (
        GeometryBasics.Point{3,Float64}(9.25, 6.0, 5.0),
        GeometryBasics.Point{3,Float64}(10.25, 6.0, 5.0),
        GeometryBasics.Point{3,Float64}(9.25, 6.0, 4.0),
        GeometryBasics.Point{3,Float64}(9.25, 7.0, 5.0),
    )

    @test all(
        isapprox(transform(point), reference; atol=1.0e-12)
        for (point, reference) in zip(landmarks, expected)
    )
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
    metrics = Dict{Symbol,@NamedTuple{area::Float64,barycenter::NTuple{3,Float64}}}()
    topologies = Dict{Symbol,Any}()
    geometry_owners = Dict{Symbol,Dict{Symbol,Int}}()
    leaf_queries = Dict{Symbol,Any}()
    face_owners = Dict{Symbol,Vector{Int}}()
    root_ids = Dict{Symbol,Int}()

    for merge_scale in merge_scales
        mtg = VPalm.build_mockup(parameters; merge_scale, rng=nothing)
        topologies[merge_scale] = _mesh_guard_topology(mtg)
        geometry_owners[merge_scale] = _mesh_guard_geometry_owners(mtg)
        root_ids[merge_scale] = node_id(mtg)
        live_leaf = only(
            node for node in descendants(mtg; symbol=:Leaf)
            if !isempty(descendants(node; symbol=:Rachis))
        )
        leaf_queries[merge_scale] = (
            petiole=length(descendants(live_leaf; symbol=:Petiole)),
            petiole_segments=length(
                descendants(live_leaf; symbol=:PetioleSegment),
            ),
            rachis=length(descendants(live_leaf; symbol=:Rachis)),
            rachis_segments=length(
                descendants(live_leaf; symbol=:RachisSegment),
            ),
            leaflets=length(descendants(live_leaf; symbol=:Leaflet)),
        )
        scene = PlantGeom.prepare_scene(
            mtg;
            compute_area=false,
            compute_barycenter=false,
        )
        face_owners[merge_scale] = scene.face2node
        triangles[merge_scale] =
            _mesh_guard_oriented_triangles(scene.merged_mesh)
        metrics[merge_scale] = _mesh_guard_area_barycenter(scene.merged_mesh)
    end

    @test !isempty(triangles[:none])
    @test all(
        triangles[merge_scale] == triangles[:none]
        for merge_scale in merge_scales
    )
    @test all(
        isapprox(metrics[merge_scale].area, metrics[:none].area; rtol=1.0e-12) &&
        all(
            isapprox.(
                metrics[merge_scale].barycenter,
                metrics[:none].barycenter;
                atol=1.0e-10,
                rtol=1.0e-12,
            ),
        )
        for merge_scale in merge_scales
    )
    @test all(
        topologies[merge_scale] == topologies[:none]
        for merge_scale in merge_scales
    )
    @test geometry_owners[:leaflet] == geometry_owners[:none]

    @test geometry_owners[:leaf][:Plant] == 0
    @test geometry_owners[:leaf][:Internode] ==
          geometry_owners[:none][:Internode]
    @test geometry_owners[:leaf][:Leaf] > 0
    @test Set(
        node_symbol for (node_symbol, count) in geometry_owners[:leaf]
        if count > 0
    ) == Set((:Internode, :Leaf))
    @test all(
        geometry_owners[:leaf][node_symbol] == 0
        for node_symbol in (:PetioleSegment, :RachisSegment, :Leaflet)
    )

    @test geometry_owners[:plant][:Plant] == 1
    @test sum(values(geometry_owners[:plant])) == 1
    @test all(==(root_ids[:plant]), face_owners[:plant])
    @test leaf_queries[:leaf] == leaf_queries[:none]
    @test leaf_queries[:plant] == leaf_queries[:none]
end
