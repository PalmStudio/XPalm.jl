@testset "Linear modulation" begin
    @test XPalm.age_relative_value(0, 0, 10, 0, 1) == 0.0
    @test XPalm.age_relative_value(5, 0, 10, 0, 1) == 0.5
    @test XPalm.age_relative_value(10, 0, 10, 0, 1) == 1.0
    @test XPalm.age_relative_value(15, 0, 10, 0, 1) == 1.0
end

@testset "Logistic modulation" begin
    @test XPalm.age_modulation_logistic(2, 3, 0, 10, 1) == 2.6894142136999513
    @test XPalm.age_modulation_logistic(2, 3, 1, 15, 2) == 2.6688409083096456
    @test XPalm.age_modulation_logistic(4, 3, 0, 10, 1) == 7.310585786300049
    @test XPalm.age_modulation_logistic(6, 1, 0, 10, 10) == 10.0
end

@testset "DailyPlantAgeModel" begin
    mtg = Palm().mtg
    m = Dict("Plant" => DailyPlantAgeModel(10))
    vars = Dict{String,Any}("Plant" => (:plant_age,))
    out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
    df = convert_outputs(out, DataFrame)
    @test df.plant_age[452] ≈ 462
    # m = ModelList(
    #     plant_age=DailyPlantAgeModel(10.0),
    #     status=(TT_since_init=[1:1:1000;],)
    # )
    # run!(m)
    # @test status(m)[:age][452] ≈ 462
end