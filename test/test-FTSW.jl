@testset "FTSW" begin
    ini_root_depth = 300.0
    soil = FTSW(ini_root_depth=ini_root_depth)
    init = soil_init_default(soil)
    init.ET0 = 2.5
    init.aPPFD = 1.0

    @test [getfield(soil, i) for i in fieldnames(typeof(soil))] == [300.0, 0.23, 0.05, 200.0, 0.05, 2000.0, 0.15, 1.0, 0.5, 0.5, 5.0, 20.0, 15.0, 18.0, 33.0]

    m = ModelList(
        FTSW(ini_root_depth=ini_root_depth),
        status=TimeStepTable{PlantSimEngine.Status}([init for i in eachrow(meteo)]))

    run!(m, meteo, executor=SequentialEx())

    @test m[:ftsw][1] ≈ 0.5660684808743338
    @test m[:ftsw][end] ≈ 0.2522536091231669
end
