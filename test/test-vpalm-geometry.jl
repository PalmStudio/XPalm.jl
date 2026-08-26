distance3(p0, p1) = sqrt(sum((p1 .- p0) .^ 2))

@testset "snag" begin
    x_scale = 10.
    y_scale = 20.
    z_scale = 30.
    hexagon_half_span = sqrt(3.0) / 4.0
    snag_ref = VPalm.SNAG
    @test snag_ref == VPalm.snag(1.0, 1.0, 1.0)
    scaled_snag = VPalm.snag(x_scale, y_scale, z_scale)

    # Test snag min/max coordinates
    ref_y_extent = let points = GeometryBasics.coordinates(snag_ref)
        x_coords_ref = getindex.(points, 1)
        y_coords_ref = getindex.(points, 2)
        z_coords_ref = getindex.(points, 3)
        @test minimum(x_coords_ref) ≈ 0.0 # x min
        @test maximum(x_coords_ref) ≈ 1.0 # x max
        @test minimum(y_coords_ref) ≈ -hexagon_half_span # y min
        @test maximum(y_coords_ref) ≈ hexagon_half_span  # y max
        @test minimum(z_coords_ref) ≈ -0.5  # z min
        @test maximum(z_coords_ref) ≈ 0.5  # z max
        maximum(abs.(y_coords_ref))
    end
    ref_z_extent = let points = GeometryBasics.coordinates(snag_ref)
        z_coords_ref = getindex.(points, 3)
        maximum(abs.(z_coords_ref))
    end

    let points = GeometryBasics.coordinates(scaled_snag)
        x_coords_scaled = getindex.(points, 1)
        y_coords_scaled = getindex.(points, 2)
        z_coords_scaled = getindex.(points, 3)
        @test minimum(x_coords_scaled) ≈ 0.0 # x min
        @test maximum(x_coords_scaled) ≈ x_scale # x max
        @test maximum(abs.(y_coords_scaled)) > ref_y_extent
        @test maximum(abs.(z_coords_scaled)) > ref_z_extent
    end
end

@testset "cylinder" begin
    x_scale = 10.
    z_scale = 30.
    cylinder_ref = VPalm.cylinder()
    @test cylinder_ref == VPalm.cylinder(1.0, 1.0)
    @test cylinder_ref.origin ≈ GeometryBasics.Point3(0.0, 0.0, 0.0)
    @test cylinder_ref.extremity ≈ GeometryBasics.Point3(0.0, 0.0, 1.0)
    @test cylinder_ref.r ≈ 1.0

    cylinder_scaled = VPalm.cylinder(x_scale, z_scale)
    @test cylinder_scaled.origin ≈ GeometryBasics.Point3(0.0, 0.0, 0.0)
    @test cylinder_scaled.extremity ≈ GeometryBasics.Point3(0.0, 0.0, z_scale)
    @test cylinder_scaled.r ≈ x_scale
end

@testset "add_geometry" begin
    mtg = VPalm.mtg_skeleton(vpalm_parameters)
    refmesh_cylinder = PlantGeom.RefMesh("cylinder", GeometryBasics.mesh(VPalm.cylinder()))
    VPalm.add_geometry!(mtg, refmesh_cylinder)

    internode_id = findfirst(i -> symbol(get_node(mtg, i)) == :Internode, 1:length(mtg))
    @test internode_id !== nothing
    internode = get_node(mtg, internode_id)
    VPalm.add_geometry!(internode, refmesh_cylinder)

    t = internode.geometry.transformation
    p0 = t(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0))
    p1 = t(GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.0))
    @test p0 ≈ GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0)
    @test distance3(p0, p1) ≈ ustrip(internode.length)
    @test distance3(p0, t(GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0))) ≈ ustrip(internode.width)
    @test distance3(p0, t(GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0))) ≈ ustrip(internode.width)

    petiole_id = findfirst(i -> symbol(get_node(mtg, i)) == :Petiole, 1:length(mtg))
    @test petiole_id !== nothing
    petiole_segment_id = findfirst(i -> symbol(get_node(mtg, i)) == :PetioleSegment, 1:length(mtg))
    @test petiole_segment_id !== nothing
    petiole_segment = get_node(mtg, petiole_segment_id)
    t_petiole = petiole_segment.geometry.transformation
    p_petiole = t_petiole(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0))
    @test distance3(p_petiole, t_petiole(GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0))) ≈ ustrip(petiole_segment.height) / 2
    @test distance3(p_petiole, t_petiole(GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0))) ≈ ustrip(petiole_segment.width) / 2
    @test distance3(p_petiole, t_petiole(GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.0))) ≈ ustrip(petiole_segment.length)

    rachis_id = findfirst(i -> symbol(get_node(mtg, i)) == :Rachis, 1:length(mtg))
    @test rachis_id !== nothing
    rachis_segment_id = findfirst(i -> symbol(get_node(mtg, i)) == :RachisSegment, 1:length(mtg))
    @test rachis_segment_id !== nothing
    rachis_segment = get_node(mtg, rachis_segment_id)
    t_rachis = rachis_segment.geometry.transformation
    p_rachis = t_rachis(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0))
    @test distance3(p_rachis, t_rachis(GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0))) ≈ ustrip(rachis_segment.height) / 2
    @test distance3(p_rachis, t_rachis(GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0))) ≈ ustrip(rachis_segment.width) / 2
    @test distance3(p_rachis, t_rachis(GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.0))) ≈ ustrip(rachis_segment.length)

    dead_leaf_id = findfirst(i -> symbol(get_node(mtg, i)) == :Leaf && !get_node(mtg, i).is_alive, 1:length(mtg))
    @test dead_leaf_id !== nothing
    @test get_node(mtg, dead_leaf_id).geometry isa PlantGeom.ExtrudedTubeGeometry

    # leaflet_id = findfirst(i -> symbol(get_node(mtg, i)) == :Leaflet, 1:length(mtg))
    # @test leaflet_id !== nothing
    # leaflet = get_node(mtg, leaflet_id)
    # @test leaflet.relative_position == 0.0
    # @test leaflet.leaflet_rank == 0.0
end

@testset "dynamic geometry uses registered status inputs" begin
    palm = Palm(
        initiation_age=0,
        parameters=XPalm.default_parameters(),
        architecture=true,
    )
    scene = XPalm.xpalm_scene(
        palm;
        architecture=true,
        environment=meteo[1:1, :],
    )

    compiled = PlantSimEngine.Advanced.refresh_bindings!(scene)
    geometry_state_binding = only(
        row for row in PlantSimEngine.Diagnostics.explain_bindings(compiled)
        if row.application_id == :Phytomer__geometry && row.input == :state
    )
    @test geometry_state_binding.source_application_ids == [:Phytomer__state]
    @test geometry_state_binding.carrier_hint != :temporal_stream
    schedule = Dict(
        row.application_id => row.execution_index
        for row in PlantSimEngine.Diagnostics.explain_schedule(compiled)
    )
    @test schedule[:Phytomer__state] < schedule[:Phytomer__geometry]

    run!(scene; steps=1, outputs=:none)

    phytomer_object = only(model_objects(scene; scale=:Phytomer))
    phytomer = PlantSimEngine.source_node(scene, phytomer_object)
    internode = phytomer[1]
    leaf = internode[1]
    @test PlantSimEngine.model_status(scene, phytomer) ===
          phytomer_object.status
    @test phytomer_object.status.is_reconstructed
    @test isfinite(ustrip(internode.width))
    @test isfinite(ustrip(internode.length))
    @test isfinite(ustrip(leaf.rachis_length))
    @test !haskey(
        MultiScaleTreeGraph.node_attributes(phytomer),
        :plantsimengine_status,
    )

    pruned_scene = XPalm.xpalm_scene(
        Palm(
            initiation_age=0,
            parameters=XPalm.default_parameters(),
            architecture=true,
        );
        architecture=true,
        environment=meteo[1:1, :],
    )
    pruned_object = only(model_objects(pruned_scene; scale=:Phytomer))
    pruned_object.status.state = :pruned
    pruned_phytomer = PlantSimEngine.source_node(pruned_scene, pruned_object)
    pruned_leaf = pruned_phytomer[1][1]
    pruned_leaf.is_alive = true

    run!(pruned_scene; steps=1, outputs=:none)

    @test pruned_object.status.state == :pruned
    @test !pruned_leaf.is_alive
end


# @testset "leaflets" begin
#     vpalm_parameters_ = copy(vpalm_parameters)
#     vpalm_parameters_["leaflet_stiffness_sd"] = 0.0u"MPa"
#     plane_ref = PlantGeom.RefMesh("Plane", PlantGeom.to_geometrybasics(VPalm.plane()))
#     mtg = VPalm.mtg_skeleton(vpalm_parameters_; rng=nothing)
#     leaflet_id = findfirst(i -> symbol(get_node(mtg, i)) == :Leaflet, 1:length(mtg))
#     @test leaflet_id !== nothing
#     leaflet_node = get_node(mtg, leaflet_id)
#     rachis_node = parent(leaflet_node)
#     VPalm.add_leaflet_geometry!(leaflet_node,
#         leaflet_node.width,
#         1.5u"m",
#         GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.5),
#         (; rachis_node.zenithal_angle_global, rachis_node.azimuthal_angle_global, rachis_node.torsion_angle_global),
#         0.0u"°",
#         0.0u"°",
#         plane_ref
#     )
#     @test isapprox(leaflet_node.zenithal_angle, 16.6575840747922u"°", atol=0.01u"°") #! this uses randomness, and we can't control it atm.
#     @test leaflet_node.lamina_angle ≈ 140.0u"°"
#     @test leaflet_node.tapering ≈ 0.5
# end
