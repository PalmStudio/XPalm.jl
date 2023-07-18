@testset "InternodeBiomass" begin
    m = ModelList(biomass=XPalm.InternodeBiomass(1.44),
        status=(carbon_allocation=fill(10.0, 2), biomass=fill(5.0, 2)))

    run!(m)

    @test m[:biomass][1] ≈ 11.944444444444445
    @test m[:biomass][2] ≈ 18.88888888888889
end