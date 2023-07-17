@testset "InternodeDimensionModel" begin
    m = ModelList(internode_dimensions=XPalm.InternodeDimensionModel(300000),
        status=(potential_height=0.10, potential_radius=0.30, biomass=10.0))

    run!(m)

    @test m[:height][1] ≈ 0.01056400961258181
    @test m[:radius][1] ≈ 0.03169202883774543

end