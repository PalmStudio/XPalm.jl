@testset "FTSW" begin
    ini_root_depth = 300.0
    soil = XPalm.FTSW(ini_root_depth=ini_root_depth)
    init = XPalm.soil_init_default(soil)
    init.ET0 = 2.5
    init.aPPFD = 1.0

    @test [getfield(soil, i) for i in fieldnames(typeof(soil))] == [300.0, 0.23, 0.05, 200.0, 0.05, 2000.0, 0.15, 1.0, 0.5, 0.5, 5.0, 20.0, 15.0, 18.0, 33.0, 0.6111111111111112, 2200.0]

    m = ModelList(
        XPalm.RootGrowthFTSW(ini_root_depth=ini_root_depth),
        XPalm.FTSW(ini_root_depth=ini_root_depth),
        status=(NamedTuple(init)..., TEff=10.0)
    )
    run!(m, meteo[1, :], executor=SequentialEx())
    @test m[:ftsw][1] ≈ 0.5604523014825595
end
