@testset "thermal_time_ftsw" begin
    ftsw_cst = 0.4
    m = ModelList(
        DegreeDaysFTSW(),
        status=(threshold_ftsw_stress=0.3, ftsw=fill(ftsw_cst, nrow(meteo)))
    )
    run!(m, meteo, executor=SequentialEx())

    @test m[:TEff][1] ≈ 9.493478260869564
    @test m[:TEff][end] ≈ 7.631656804733727
end
