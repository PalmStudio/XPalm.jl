@testset "RootGrowthFTSW" begin
    ini_root_depth = 30.0
    roots = RootGrowthFTSW(ini_root_depth=ini_root_depth)
    @test [getfield(roots, i) for i in fieldnames(typeof(roots))] == [30.0, 0.3, 0.2]

end

@testset "RootGrowthFTSW + FTSW" begin
    ini_root_depth = 300.0
    soil = FTSW(ini_root_depth=ini_root_depth)
    init = soil_init_default(soil)
    init.ET0 = 2.5
    init.aPPFD = 1.0

    m = ModelList(
        FTSW(ini_root_depth=ini_root_depth),
        RootGrowthFTSW(ini_root_depth=ini_root_depth),
        # status=TimeStepTable{PlantSimEngine.Status}([init for i in eachrow(meteo)])
        status=(soil_depth=fill(2000, nrow(meteo)), TEff=fill(9.0, nrow(meteo)), ftsw=fill(0.5, nrow(meteo)))
    )
    # @test to_initialize(m) == (root_growth=(:soil_depth, :TEff),)


    run!(m, meteo, executor=SequentialEx())

    @test m[:ftsw][1] ≈ 0.6111111111111112

    @test m[:ftsw][end] ≈ 0.9365282961879335

    @test m[:root_depth][1] == 302.7
    @test m[:root_depth][end] == 2000.0
end
