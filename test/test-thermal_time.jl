@testset "thermal_time" begin
    m = ModelList(
        thermal_time=DailyDegreeDays())
    run!(m, meteo, executor=SequentialEx()) #!!! bug

    @test m[:TEff][1]
    @test m[:TEff][end]
end
