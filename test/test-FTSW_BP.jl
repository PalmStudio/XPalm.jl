@testset "FTSW_BP" begin
    ini_root_depth = 300.0
    soil = FTSW_BP(ini_root_depth=ini_root_depth)
    @test [getfield(soil, i) for i in fieldnames(typeof(soil))] == [300.0, 0.23, 0.05, 200.0, 0.05, 2000.0, 0.15, 1.0, 0.5, 0.5, 5.0, 20.0, 15.0, 18.0, 33.0, 5.0, 20.0, 15.0, 18.0, 33.0]

    m = ModelList(
        FTSW_BP(ini_root_depth=ini_root_depth),
        status=(ET0=2.5, tree_ei=0.8, root_depth=fill(ini_root_depth, nrow(meteo)))
    )
    run!(m, meteo, executor=SequentialEx())

    @test m[:ftsw][1] ≈ 0.2962962962962963
    @test m[:ftsw][end] ≈ 0.0
end
