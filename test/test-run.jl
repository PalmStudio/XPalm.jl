
@testset "xpalm" begin
    df = xpalm(meteo; vars=Dict("Scene" => (:lai,)), sink=DataFrame)
    @test only(unique(df.organ)) == "Scene"
    @test df.lai[1] == 0.000272
    @test df.lai[end] == 0.023936000000000016
end