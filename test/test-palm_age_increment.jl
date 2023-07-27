@testset "DailyPlantAgeModel" begin
    m = ModelList(plant_age=XPalm.DailyPlantAgeModel(10.0),
        status=(TT_since_init=[1:1:1000;],))

    run!(m)

    @test m[:age][452] ≈ 462

end