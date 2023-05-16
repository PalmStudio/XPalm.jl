@testset "FTSW" begin
    ini_root_depth = 300.0
    soil = FTSW(ini_root_depth=ini_root_depth)
    @test [getfield(soil, i) for i in fieldnames(typeof(soil))] == [300.0, 0.23, 0.05, 200.0, 0.05, 2000.0, 0.15, 1.0, 0.5, 0.5, 5.0, 20.0, 15.0, 18.0, 33.0]

    m = ModelList(
        FTSW(ini_root_depth=ini_root_depth),
        status=(ET0=1.0, tree_ei=0.8, root_depth=fill(ini_root_depth, nrow(meteo)))
    )
    run!(m, meteo)

    @test m[:ftsw][1] ≈ 0.5953044330938972
    @test m[:ftsw][end] ≈ 0.4202599224549292
end
