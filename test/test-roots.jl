@testset "RootGrowthFTSW" begin
    ini_root_depth = 30.0
    roots = RootGrowthFTSW(ini_root_depth=ini_root_depth)
    @test [getfield(roots, i) for i in fieldnames(typeof(roots))] == [30.0, 0.3, 0.2]
end

@testset "RootGrowthFTSW + FTSW" begin
    ini_root_depth = 300.0
    soil = FTSW(ini_root_depth=ini_root_depth)
    init = Models.soil_init_default(soil)
    init.ET0 = 2.5
    init.aPPFD = 1.0

    @testset "Single soil object" begin
        scene = test_scene(
            :Soil,
            FTSW(ini_root_depth=ini_root_depth),
            RootGrowthFTSW(ini_root_depth=ini_root_depth);
            status=Status(; NamedTuple(init)..., soil_depth=2000.0, TEff=9.0),
            environment=meteo[1:1, :],
        )
        run!(scene)
        status = test_status(scene, :Soil)
        @test status.ftsw ≈ 0.5824964394002472
        @test status.root_depth == 302.7
    end

    @testset "Multi-step scene" begin
        root_meteo = meteo[1:2, :]
        scene = test_scene(
            :Soil,
            RootGrowthFTSW(ini_root_depth=ini_root_depth),
            FTSW(ini_root_depth=ini_root_depth);
            status=Status(; NamedTuple(init)..., soil_depth=2000.0, TEff=9.0),
            environment=root_meteo,
        )
        sim = run!(
            scene;
            steps=nrow(root_meteo),
            outputs=[
                OutputRequest(:Soil, :root_depth),
                OutputRequest(:Soil, :ftsw),
            ],
        )
        root_depth = output_values(sim, :root_depth)
        ftsw = output_values(sim, :ftsw)
        @test root_depth[1] ≈ 302.7
        @test root_depth[end] ≈ 305.4
        @test ftsw[1] ≈ 0.5824964394002472
    end
end
