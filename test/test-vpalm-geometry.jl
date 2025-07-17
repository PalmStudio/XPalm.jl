@testset "snag" begin
    x_scale = 10.
    y_scale = 20.
    z_scale = 30.
    snag_ref = VPalm.SNAG
    @test snag_ref == VPalm.snag(1.0, 1.0, 1.0)
    scaled_snag = VPalm.snag(x_scale, y_scale, z_scale)

    # Test snag min/max coordinates
    let points = vertices(snag_ref)
        x_coords_ref = [point.coords.x for point in points]
        y_coords_ref = [point.coords.y for point in points]
        z_coords_ref = [point.coords.z for point in points]
        @test minimum(x_coords_ref) ≈ 0.0u"m" # x min
        @test maximum(x_coords_ref) ≈ 1.0u"m" # x max
        @test minimum(y_coords_ref) ≈ -0.5u"m" # y min
        @test maximum(y_coords_ref) ≈ 0.5u"m"  # y max
        @test minimum(z_coords_ref) ≈ -0.5u"m"  # z min
        @test maximum(z_coords_ref) ≈ 0.5u"m"  # z max
    end

    let points = vertices(scaled_snag)
        x_coords_scaled = [point.coords.x for point in points]
        y_coords_scaled = [point.coords.y for point in points]
        z_coords_scaled = [point.coords.z for point in points]
        @test minimum(x_coords_scaled) ≈ 0.0u"m" # x min
        @test maximum(x_coords_scaled) ≈ x_scale * u"m" # x max
        @test minimum(y_coords_scaled) ≈ -y_scale / 2 * u"m" # y min
        @test maximum(y_coords_scaled) ≈ y_scale / 2 * u"m" # y max
        @test minimum(z_coords_scaled) ≈ -z_scale / 2 * u"m" # z min
        @test maximum(z_coords_scaled) ≈ z_scale / 2 * u"m" # z max
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
    let points = vertices(cylinder_scaled)
        x_coords = [point.coords.x for point in points]
        y_coords = [point.coords.y for point in points]
        z_coords = [point.coords.z for point in points]

        @test isapprox(maximum(abs.(x_coords)), x_scale * u"m", atol=0.05u"m")  # rayon en x
        @test isapprox(maximum(abs.(y_coords)), x_scale * u"m", atol=0.05u"m")  # rayon en y
        @test isapprox(maximum(z_coords), z_scale * u"m", atol=0.05u"m")        # hauteur
        @test isapprox(minimum(z_coords), 0.0u"m")              # base du cylindre
    end

    # Check the vertices of the elliptical cylinder
    let points = vertices(elliptical_cylinder_scaled)
        x_coords = [point.coords.x for point in points]
        y_coords = [point.coords.y for point in points]
        z_coords = [point.coords.z for point in points]

        @test isapprox(maximum(abs.(x_coords)), x_scale * u"m", atol=0.05u"m")  # rayon en x
        @test isapprox(maximum(abs.(y_coords)), y_scale * u"m", atol=0.05u"m")  # rayon en y
        @test isapprox(maximum(z_coords), z_scale * u"m", atol=0.05u"m")        # hauteur
        @test isapprox(minimum(z_coords), 0.0u"m", atol=0.05u"m")              # base du cylindre
    end
end

@testset "add_geometry" begin
    mtg = VPalm.mtg_skeleton(vpalm_parameters)
    refmesh_cylinder = PlantGeom.RefMesh("cylinder", VPalm.cylinder())
    refmesh_snag = PlantGeom.RefMesh("Snag", VPalm.snag())
    refmesh_plane = PlantGeom.RefMesh("Plane", VPalm.plane())
    VPalm.add_geometry!(mtg, refmesh_cylinder, refmesh_snag, refmesh_plane)

    internode_id = findfirst(i -> symbol(get_node(mtg, i)) == "Internode", 1:length(mtg))
    @test internode_id !== nothing
    internode = get_node(mtg, internode_id)
    VPalm.add_geometry!(internode, refmesh_cylinder, refmesh_snag, refmesh_plane)

    scale = internode.geometry.transformation.transforms[1]
    @test scale.factors[1] ≈ ustrip(internode.width)
    @test scale.factors[2] == scale.factors[1]
    @test scale.factors[3] ≈ ustrip(internode.length)

    translate = internode.geometry.transformation.transforms[2]
    @test translate.offsets[1] == 0.0u"m"
    @test translate.offsets[2] == 0.0u"m"
    @test translate.offsets[3] == 0.0u"m"

    petiole_id = findfirst(i -> symbol(get_node(mtg, i)) == "Petiole", 1:length(mtg))
    @test petiole_id !== nothing
    petiole = get_node(mtg, petiole_id)

    rachis_id = findfirst(i -> symbol(get_node(mtg, i)) == "Rachis", 1:length(mtg))
    @test rachis_id !== nothing
    rachis = get_node(mtg, rachis_id)

    leaflet_id = findfirst(i -> symbol(get_node(mtg, i)) == "Leaflet", 1:length(mtg))
    @test leaflet_id !== nothing
    leaflet = get_node(mtg, leaflet_id)
    @test leaflet.relative_position == 0.0
    @test leaflet.leaflet_rank == 0.0
end


@testset "leaflets" begin
    vpalm_parameters_ = copy(vpalm_parameters)
    vpalm_parameters_["leaflet_stiffness_sd"] = 0.0u"MPa"
    plane_ref = PlantGeom.RefMesh("Plane", VPalm.plane())
    mtg = VPalm.mtg_skeleton(vpalm_parameters_; rng=StableRNG(vpalm_parameters_["seed"]))
    leaflet_id = findfirst(i -> symbol(get_node(mtg, i)) == "Leaflet", 1:length(mtg))
    @test leaflet_id !== nothing
    leaflet_node = get_node(mtg, leaflet_id)
    rachis_node = parent(leaflet_node)
    VPalm.add_leaflet_geometry!(leaflet_node,
        leaflet_node.width,
        1.5u"m",
        Meshes.Point(0.0, 0.0, 1.5),
        (; rachis_node.zenithal_angle_global, rachis_node.azimuthal_angle_global, rachis_node.torsion_angle_global),
        0.0u"°",
        0.0u"°",
        plane_ref
    )
    @test isapprox(leaflet_node.zenithal_angle, 17.36u"°", atol=0.01u"°") #! this uses randomness, and we can't control it atm.
    @test leaflet_node.lamina_angle ≈ 140.0u"°"
    @test leaflet_node.tapering ≈ 0.5
end
