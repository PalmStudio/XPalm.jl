@testset "LeafCarbonDemandModelPotentialArea" begin
    m = ModelList(carbon_demand=XPalm.LeafCarbonDemandModelPotentialArea(80.0, 1.44, 0.35),
        status=(potential_area=[10.0; 10.0; 11.0], state=["undetermined"; "undetermined"; "undetermined"],))

    run!(m)

    @test m[:carbon_demand][1] ≈ 0.0
    @test m[:carbon_demand][2] ≈ 0.5890486225480889
end