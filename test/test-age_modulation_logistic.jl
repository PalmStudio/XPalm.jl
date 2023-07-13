@testset "Age dependent computations" begin
    @test XPalm.age_modulation_logistic(2, 3, 0, 10, 1) == 2.6894142136999513
    @test XPalm.age_modulation_logistic(2, 3, 1, 15, 2) == 2.6688409083096456
    @test XPalm.age_modulation_logistic(4, 3, 0, 10, 1) == 7.310585786300049
    @test XPalm.age_modulation_logistic(6, 1, 0, 10, 10) == 10.0
end