# Define dummy functions if they are not yet implemented
# Create a dummy test file
df = CSV.read(joinpath(@__DIR__, "references/6_EW01.22_17_kanan_unbent.csv"), DataFrame)

# Set test parameters
pas = 0.02u"m"  # in meter. -> Length of the segments that discretize the object.
Ncalc = 100 # number of points used in the grid that discretized the section.
Nboucle = 15 # if we want to compute the torsion after the bending step by step instead of
elastic_modulus = 2000.0u"MPa"
shear_modulus = 400.0u"MPa"

atol_length = 1e-3u"m" # mm tolerance

ref = CSV.read(joinpath(@__DIR__, "references/6_EW01.22_17_kanan_unbent_bend.csv"), DataFrame)
@testset "bend works" begin
    # Dummy input data for bend function
    # Test the input data
    @test length(df.type) == length(df.width) == length(df.height) == length(df.torsion) == length(df.x) == length(df.y) == length(df.z) == length(df.mass) == length(df.mass_right) == length(df.mass_left) == length(df.distance_application)
    # Call the function
    out = VPalm.bend(
        df.type, df.width * u"m", df.height * u"m", df.torsion * u"°", df.x * u"m", df.y * u"m", df.z * u"m", df.mass * u"kg", df.mass_right * u"kg", df.mass_left * u"kg",
        df.distance_application * u"m", elastic_modulus, shear_modulus, pas, Ncalc, Nboucle;
        verbose=false
    )

    # Test length of elastic_modulus and shear_modulus
    @test_throws MethodError VPalm.bend(
        df.type, df.width * u"m", df.height * u"m", df.torsion * u"°", df.x * u"m", df.y * u"m", df.z * u"m", df.mass * u"kg", df.mass_right * u"kg", df.mass_left * u"kg",
        df.distance_application * u"m", fill(elastic_modulus, length(df) -1), shear_modulus, pas, Ncalc, Nboucle;
        verbose=false, angle_max = 0.0u"°"
    )
    @test_throws MethodError VPalm.bend(
        df.type, df.width * u"m", df.height * u"m", df.torsion * u"°", df.x * u"m", df.y * u"m", df.z * u"m", df.mass * u"kg", df.mass_right * u"kg", df.mass_left * u"kg",
        df.distance_application * u"m", elastic_modulus, fill(shear_modulus, length(df) -1), pas, Ncalc, Nboucle;
        verbose=false, angle_max = 0.0u"°"
    )

    # CSV.write(joinpath(@__DIR__, "references/6_EW01.22_17_kanan_unbent_bend.csv"), DataFrame(out))
    ref_points = [Meshes.Point(row.x, row.y, row.z) for row in eachrow(ref)]
    for (ref_p, p) in zip(ref_points, out.points)
        @test isapprox(ref_p, p, atol=atol_length)
    end
    @test only(unique(unit.(out.length))) == u"m"
    @test ref.length * u"m" ≈ out.length atol = atol_length
    @test [ref.angle_xy[2]; ref.angle_xy[2:end]] * u"°" ≈ out.angle_xy atol = 1e-2
    @test [ref.angle_xz[2]; ref.angle_xz[2:end]] * u"°" ≈ out.angle_xz atol = 1e-2
    @test [ref.torsion[2]; ref.torsion[2:end]] * u"°" ≈ out.torsion atol = 1e-2
end

@testset "unbend" begin
    bent_data = CSV.read(joinpath(@__DIR__, "references/6_EW01.22_17_kanan.txt"), DataFrame, header=false) |> Matrix |> adjoint

    unbent_points = VPalm.unbend(
        bent_data[:, 1] * u"m", bent_data[:, 5]
    )

    ref_points_data = CSV.read(joinpath(@__DIR__, "references/6_EW01.22_17_kanan_unbent.csv"), DataFrame)
    ref_points = [Meshes.Point(row.x, row.y, row.z) for row in eachrow(ref_points_data)]

    @test length(ref_points) == length(unbent_points)
    @test all(isapprox(ref, unbent, atol=atol_length) for (ref, unbent) in zip(ref_points, unbent_points))
end