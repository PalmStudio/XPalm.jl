@testset "RootGrowthFTSW" begin
    ini_root_depth = 30.0
    roots = RootGrowthFTSW(ini_root_depth=ini_root_depth)
    @test [getfield(roots, i) for i in fieldnames(typeof(roots))] == [30.0, 0.3, 0.2]
end

@testset "RootGrowthFTSW + FTSW" begin
    ini_root_depth = 300.0
    m = ModelList(
        FTSW(ini_root_depth=ini_root_depth),
        RootGrowthFTSW(ini_root_depth=ini_root_depth),
    )

    @test to_initialize(m) == (soil_water=(:ET0, :aPPFD), root_growth=(:TEff,))

    m = ModelList(
        FTSW(ini_root_depth=ini_root_depth),
        RootGrowthFTSW(ini_root_depth=ini_root_depth),
        status=(ET0=1.0, aPPFD=1.0, TEff=fill(9.0, nrow(meteo)))
    )

    run!(m, meteo, executor=SequentialEx())

    @test m[:ftsw][1] ≈ 0.5953044330938972
    @test m[:ftsw][end] ≈ 0.9365282961879335

    @test m[:root_depth][1] == 302.7
    @test m[:root_depth][end] == 2200.0
end
