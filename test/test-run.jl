
@testset "xpalm" begin
    df = xpalm(meteo, DataFrame; vars=Dict("Scene" => (:lai,)))
    @test only(unique(df.organ)) == "Scene"
    @test df.lai[1] == 0.000272
    @test df.lai[end] == 1.463098873591723
end