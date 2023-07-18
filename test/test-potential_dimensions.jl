@testset "PotentialInternodeDimensionModel" begin
    m = ModelList(internode_dimensions=XPalm.PotentialInternodeDimensionModel(900.0, 150.0, 900.0, 150.0),
        status=(TT_since_init=2000, final_potential_height=0.30, final_potential_radius=10.0,))

    run!(m)

    @test m[:potential_height][1] ≈ 0.29980411039873417
    @test m[:potential_radius][1] ≈ 9.993470346624472

end