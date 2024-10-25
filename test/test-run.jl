
@testset "Palm" begin
    p = XPalm.Palm()

    scene = p.mtg
    soil = scene[1]
    plant = scene[2]
    roots = plant[1]

    df = xpalm(meteo; vars=Dict("Scene" => (:lai,)), sink=DataFrame)

    @test only(unique(df.organ)) == "Scene"
    @test df.lai[1] == 0.000272
    @test df.lai[end] == 0.10009599999999906
end