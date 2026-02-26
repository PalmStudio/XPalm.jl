mesh_points(mesh) = GeometryBasics.coordinates(PlantGeom.to_geometrybasics(mesh))

@testset "snag" begin
    x_scale = 10.
    y_scale = 20.
    z_scale = 30.
    snag_ref = VPalm.SNAG
    @test snag_ref == VPalm.snag(1.0, 1.0, 1.0)
    scaled_snag = VPalm.snag(x_scale, y_scale, z_scale)

    # Test snag min/max coordinates
    let points = mesh_points(snag_ref)
        x_coords_ref = getindex.(points, 1)
        y_coords_ref = getindex.(points, 2)
        z_coords_ref = getindex.(points, 3)
        @test minimum(ustrip.(x_coords_ref)) ≈ 0.0 # x min
        @test maximum(ustrip.(x_coords_ref)) ≈ 1.0 # x max
        @test minimum(ustrip.(y_coords_ref)) ≈ -0.5 # y min
        @test maximum(ustrip.(y_coords_ref)) ≈ 0.5  # y max
        @test minimum(ustrip.(z_coords_ref)) ≈ -0.5  # z min
        @test maximum(ustrip.(z_coords_ref)) ≈ 0.5  # z max
    end

    let points = mesh_points(scaled_snag)
        x_coords_scaled = getindex.(points, 1)
        y_coords_scaled = getindex.(points, 2)
        z_coords_scaled = getindex.(points, 3)
        @test minimum(ustrip.(x_coords_scaled)) ≈ 0.0 # x min
        @test maximum(ustrip.(x_coords_scaled)) ≈ x_scale # x max
        @test minimum(ustrip.(y_coords_scaled)) ≈ -y_scale / 2 # y min
        @test maximum(ustrip.(y_coords_scaled)) ≈ y_scale / 2 # y max
        @test minimum(ustrip.(z_coords_scaled)) ≈ -z_scale / 2 # z min
        @test maximum(ustrip.(z_coords_scaled)) ≈ z_scale / 2 # z max
    end
end

@testset "cylinder and elliptical cylinder" begin
    x_scale = 10.
    y_scale = 20.
    z_scale = 30.
    # Test the default cylinder
    cylinder_ref = VPalm.cylinder()
    @test cylinder_ref == VPalm.cylinder(1.0, 1.0)

    # Test the scaled cylinder
    cylinder_scaled = VPalm.cylinder(x_scale, z_scale)
    elliptical_cylinder_scaled = VPalm.elliptical_cylinder(x_scale, y_scale, z_scale)

    # Check the vertices of the scaled cylinder
    let points = mesh_points(cylinder_scaled)
        x_coords = ustrip.(getindex.(points, 1))
        y_coords = ustrip.(getindex.(points, 2))
        z_coords = ustrip.(getindex.(points, 3))

        @test isapprox(maximum(abs.(x_coords)), x_scale, atol=0.05)  # rayon en x
        @test isapprox(maximum(abs.(y_coords)), x_scale, atol=0.05)  # rayon en y
        @test isapprox(maximum(z_coords), z_scale, atol=0.05)        # hauteur
        @test isapprox(minimum(z_coords), 0.0)                        # base du cylindre
    end

    # Check the vertices of the elliptical cylinder
    let points = mesh_points(elliptical_cylinder_scaled)
        x_coords = ustrip.(getindex.(points, 1))
        y_coords = ustrip.(getindex.(points, 2))
        z_coords = ustrip.(getindex.(points, 3))

        @test isapprox(maximum(abs.(x_coords)), x_scale, atol=0.05)  # rayon en x
        @test isapprox(maximum(abs.(y_coords)), y_scale, atol=0.05)  # rayon en y
        @test isapprox(maximum(z_coords), z_scale, atol=0.05)        # hauteur
        @test isapprox(minimum(z_coords), 0.0, atol=0.05)            # base du cylindre
    end
end

@testset "add_geometry" begin
    mtg = VPalm.mtg_skeleton(vpalm_parameters)
    refmesh_cylinder = PlantGeom.RefMesh("cylinder", PlantGeom.to_geometrybasics(VPalm.cylinder()))
    refmesh_snag = PlantGeom.RefMesh("Snag", PlantGeom.to_geometrybasics(VPalm.snag()))
    refmesh_plane = PlantGeom.RefMesh("Plane", PlantGeom.to_geometrybasics(VPalm.plane()))
    VPalm.add_geometry!(mtg, refmesh_cylinder, refmesh_snag, refmesh_plane)

    internode_id = findfirst(i -> symbol(get_node(mtg, i)) == :Internode, 1:length(mtg))
    @test internode_id !== nothing
    internode = get_node(mtg, internode_id)
    VPalm.add_geometry!(internode, refmesh_cylinder, refmesh_snag, refmesh_plane)

    t = internode.geometry.transformation
    p0 = t(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0))
    p1 = t(GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.0))
    @test p0 ≈ GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0)
    @test sqrt(sum((p1 .- p0) .^ 2)) ≈ ustrip(internode.length)

    petiole_id = findfirst(i -> symbol(get_node(mtg, i)) == :Petiole, 1:length(mtg))
    @test petiole_id !== nothing
    petiole = get_node(mtg, petiole_id)

    rachis_id = findfirst(i -> symbol(get_node(mtg, i)) == :Rachis, 1:length(mtg))
    @test rachis_id !== nothing
    rachis = get_node(mtg, rachis_id)

    leaflet_id = findfirst(i -> symbol(get_node(mtg, i)) == :Leaflet, 1:length(mtg))
    @test leaflet_id !== nothing
    leaflet = get_node(mtg, leaflet_id)
    @test leaflet.relative_position == 0.0
    @test leaflet.leaflet_rank == 0.0
end


@testset "leaflets" begin
    vpalm_parameters_ = copy(vpalm_parameters)
    vpalm_parameters_["leaflet_stiffness_sd"] = 0.0u"MPa"
    plane_ref = PlantGeom.RefMesh("Plane", PlantGeom.to_geometrybasics(VPalm.plane()))
    mtg = VPalm.mtg_skeleton(vpalm_parameters_; rng=nothing)
    leaflet_id = findfirst(i -> symbol(get_node(mtg, i)) == :Leaflet, 1:length(mtg))
    @test leaflet_id !== nothing
    leaflet_node = get_node(mtg, leaflet_id)
    rachis_node = parent(leaflet_node)
    VPalm.add_leaflet_geometry!(leaflet_node,
        leaflet_node.width,
        1.5u"m",
        GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.5),
        (; rachis_node.zenithal_angle_global, rachis_node.azimuthal_angle_global, rachis_node.torsion_angle_global),
        0.0u"°",
        0.0u"°",
        plane_ref
    )
    @test isapprox(leaflet_node.zenithal_angle, 16.6575840747922u"°", atol=0.01u"°") #! this uses randomness, and we can't control it atm.
    @test leaflet_node.lamina_angle ≈ 140.0u"°"
    @test leaflet_node.tapering ≈ 0.5
end
