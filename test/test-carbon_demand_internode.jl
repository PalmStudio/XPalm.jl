@testset "InternodeCarbonDemandModel" begin
    m = ModelList(
        biomass=XPalm.InternodeCarbonDemandModel(3000.0, 1.44),
        status=(potential_height=[0.1, 0.101], potential_radius=[0.30, 0.30])
    )
    run!(m)

    @test m[:carbon_demand][1] ≈ 0.0
    @test m[:carbon_demand][2] ≈ 0.5890486225480889
end


@testset "LeafCarbonDemandModelPotentialArea" begin
    m = ModelList(carbon_demand=XPalm.LeafCarbonDemandModelPotentialArea(80.0, 1.44, 0.35),
        status=(potential_area=[10.0; 10.0; 11.0], state=["undetermined"; "undetermined"; "undetermined"],))

    run!(m)

    @test m[:carbon_demand][1] ≈ 0.0
    @test m[:carbon_demand][2] ≈ 0.5890486225480889
end