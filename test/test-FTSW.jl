@testset "FTSW" begin
    ini_root_depth = 300.0
    soil = FTSW(ini_root_depth=ini_root_depth)
    init = Models.soil_init_default(soil)
    init.ET0 = 2.5
    init.aPPFD = 1.0

    @test [getfield(soil, i) for i in fieldnames(typeof(soil))] == [300.0, 0.23, 0.05, 200.0, 0.05, 2000.0, 0.15, 1.0, 0.5, 0.5, 5.0, 20.0, 15.0, 18.0, 33.0, 0.6111111111111112, 2200.0]

    scene = test_scene(
        :Soil,
        RootGrowthFTSW(ini_root_depth=ini_root_depth),
        FTSW(ini_root_depth=ini_root_depth);
        status=Status(aPPFD=1.0, ET0=2.5, TEff=10.0),
        environment=meteo[1:1, :],
    )
    simulation = run!(scene; outputs=:all)
    @test test_status(scene, :Soil).ftsw ≈ 0.5819197102523261
    @test any(
        row -> row.application_id == :root_growth && row.variable == :root_depth,
        collect_outputs(simulation; sink=nothing),
    )
end


@testset "FTSW_BP" begin
    ini_root_depth = 300.0

    scene = test_scene(
        :Soil,
        RootGrowthFTSW(ini_root_depth=ini_root_depth),
        FTSW_BP(ini_root_depth=ini_root_depth);
        status=Status(aPPFD=1.0, ET0=2.5, TEff=10.0),
        environment=meteo[1:1, :],
    )
    simulation = run!(scene; outputs=:all)
    @test test_status(scene, :Soil).ftsw ≈ 0.5592225889255592
    @test any(
        row -> row.application_id == :root_growth && row.variable == :root_depth,
        collect_outputs(simulation; sink=nothing),
    )
end
