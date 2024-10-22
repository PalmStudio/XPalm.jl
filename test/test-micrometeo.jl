@testset "ET0_BP" begin
    m = ModelList(ET0_BP())
    run!(m, meteo[1, :])
    @test m[:ET0][1] ≈ 2.82260378306658
end

@testset "thermal_time" begin
    m = ModelList(
        thermal_time=DailyDegreeDays(),
        status=(TEff=fill(-Inf, nrow(meteo)), TT_since_init=fill(0.0, nrow(meteo)))
    )

    run!(m, meteo, executor=SequentialEx())

    @test m[:TEff][1] ≈ 9.493478260869564
    @test m[:TEff][end] ≈ 7.631656804733727
    @test m[:TT_since_init][10] ≈ 96.18582446712631
    @test m[:TT_since_init][end] ≈ 8350.554765084204
end

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
