@testset "FinalPotentialInternodeDimensionModel" begin
    m = ModelList(internode_final_potential_dimensions=XPalm.FinalPotentialInternodeDimensionModel(2920, 2920, 0.0001, 0.0001, 0.03, 0.30),
        status=(initiation_age = 1825))

    run!(m)

    @test m[:final_potential_height][1] ≈ 
    @test m[:final_potential_radius][1] ≈ 

end