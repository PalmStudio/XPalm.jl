@testset "thermal_time" begin

    m = ModelList(
        thermal_time=DailyDegreeDays(),
        status=(TEff=fill(-Inf, nrow(meteo)), TT_since_init=fill(-Inf, nrow(meteo))))


    run!(m, meteo, executor=SequentialEx())

    @test m[:TEff][1] ≈ 9.493478260869564
    @test m[:TEff][end] ≈ 7.631656804733727
    @test m[:TT_since_init][10] ≈ 96.18582446712631
    @test m[:TT_since_init][end] ≈ 8350.554765084204

end
