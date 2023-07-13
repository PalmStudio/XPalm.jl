@testset "Age dependent computations" begin
    @test XPalm.age_relative_value(0, 0, 10, 0, 1) == 0.0
    @test XPalm.age_relative_value(5, 0, 10, 0, 1) == 0.5
    @test XPalm.age_relative_value(10, 0, 10, 0, 1) == 1.0
    @test XPalm.age_relative_value(15, 0, 10, 0, 1) == 1.0
end