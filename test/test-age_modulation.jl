@testset "Age dependent computations" begin
    @test XPalm.age_relative_var(0, 0, 10, 0, 1) == 0.0
    @test XPalm.age_relative_var(5, 0, 10, 0, 1) == 0.5
    @test XPalm.age_relative_var(10, 0, 10, 0, 1) == 1.0
    @test XPalm.age_relative_var(15, 0, 10, 0, 1) == 1.0
end