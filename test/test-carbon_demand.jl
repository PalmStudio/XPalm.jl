@testset "InternodeCarbonDemandModel" begin
    m = ModelList(biomass=XPalm.InternodeCarbonDemandModel(3000.0, 1.44),
        status=(potential_height=[0.1, 0.101], potential_radius=[0.30, 0.30]))

    run!(m)

    @test m[:carbon_demand][1] ≈ 0.0
    @test m[:carbon_demand][2] ≈ 0.5890486225480889
end