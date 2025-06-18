@testset "dist_and_angles_to_xyz" begin
    # Test different vector sizes
    @test_throws ErrorException VPalm.dist_and_angles_to_xyz([1.0], [1.0, 2.0], [1.0])
    @test_throws ErrorException VPalm.dist_and_angles_to_xyz([1.0], [1.0], [1.0, 2.0])

    # Test simple case (90° to XY, 0° to XZ)
    dist = [1.0]
    angle_xy = [π / 2] # 90°
    angle_xz = [0.0]
    points = VPalm.dist_and_angles_to_xyz([1.0], angle_xy, angle_xz)
    @test points[1] ≈ Meshes.Point(0.0, 0.0, 1.0)

    # Test simple case (0° to XY, 0° to XZ)
    dist = [1.0]
    angle_xy = [0.0]
    angle_xz = [0.0]
    points = VPalm.dist_and_angles_to_xyz(dist, angle_xy, angle_xz)
    @test points[1] ≈ Meshes.Point(1.0, 0.0, 0.0)

    # Test 2 segments
    dist = [1.0, 1.0]
    angle_xy = [0.0, π / 4]  # 0° then 45°
    angle_xz = [0.0, 0.0]
    points = VPalm.dist_and_angles_to_xyz(dist, angle_xy, angle_xz)

    @test length(points) == 2
    @test points[1] ≈ Meshes.Point(1.0, 0.0, 0.0)
    @test points[2] ≈ Meshes.Point(1.0 + cos(π / 4), 0.0, sin(π / 4))

    # Test with 90° in the XZ plane rotation
    dist = [1.0]
    angles_xy = [0.0]
    angles_xz = [π / 2]  # 90° dans le plan XZ
    points = VPalm.dist_and_angles_to_xyz(dist, angles_xy, angles_xz)
    @test points[1] ≈ Meshes.Point(0.0, 1.0, 0.0)
end

@testset "xyz_to_dist_and_angles" begin
    # Test simple case (90° to XY, 0° to XZ)
    dist_p2p1, vangle_xy, vangle_xz = VPalm.xyz_to_dist_and_angles([Meshes.Point(0.0, 0.0, 1.0)])
    @test dist_p2p1 ≈ [1.0u"m"]
    @test vangle_xy ≈ [π / 2]
    @test vangle_xz ≈ [0.0]

    # Test simple case (0° to XY, 0° to XZ)
    dist_p2p1, vangle_xy, vangle_xz = VPalm.xyz_to_dist_and_angles([Meshes.Point(1.0, 0.0, 0.0)])
    @test dist_p2p1 ≈ [1.0u"m"]
    @test vangle_xy ≈ [0.0]
    @test vangle_xz ≈ [0.0]

    # Test 2 segments
    # x = [1.0, 1.0 + cos(π / 4)]
    # y = [0.0, 0.0]
    # z = [0.0, sin(π / 4)]
    # points = VPalm.xyz_to_dist_and_angles(x, y, z)

    dist_p2p1, vangle_xy, vangle_xz = VPalm.xyz_to_dist_and_angles([Meshes.Point(1.0, 0.0, 0.0), Meshes.Point(1.0 + cos(π / 4), 0.0, sin(π / 4))])
    @test dist_p2p1 ≈ [1.0u"m", 1.0u"m"]
    @test vangle_xy ≈ [0.0, π / 4]
    @test vangle_xz ≈ [0.0, 0.0]
end