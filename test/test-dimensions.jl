@testset "InternodeDimensionModel" begin
    m = ModelList(
        internode_dimensions=InternodeDimensionModel(300000),
        status=(potential_height=0.10, potential_radius=0.30, biomass=10.0)
    )
    run!(m)
    @test m[:height][1] ≈ 0.01056400961258181
    @test m[:radius][1] ≈ 0.03169202883774543
end

@testset "FinalPotentialInternodeDimensionModel" begin
    m = ModelList(
        internode_final_potential_dimensions=FinalPotentialInternodeDimensionModel(2920, 2920, 0.0001, 0.0001, 0.03, 0.30),
        status=(initiation_age=1825,)
    )
    run!(m)
    @test m[:final_potential_height][1] ≈ 0.0187875
    @test m[:final_potential_radius][1] ≈ 0.1875375
end


@testset "PotentialInternodeDimensionModel" begin
    m = ModelList(
        internode_dimensions=PotentialInternodeDimensionModel(900.0, 150.0, 900.0, 150.0),
        status=(TT_since_init=2000, final_potential_height=0.30, final_potential_radius=10.0,)
    )
    run!(m)
    @test m[:potential_height][1] ≈ 0.29980411039873417
    @test m[:potential_radius][1] ≈ 9.993470346624472
end