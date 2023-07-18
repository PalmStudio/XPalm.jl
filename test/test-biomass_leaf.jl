@testset "BiomassFromArea" begin
    m = ModelList(biomass_from_area=XPalm.BiomassFromArea(80.0, 0.35),
        status=(leaf_area=8.2,))

    run!(m)

    @test m[:biomass][1] ≈ 1874.2857142857144

    m = ModelList(biomass=XPalm.LeafBiomass(1.44),
        status=(carbon_allocation=[5:0.1:9;], biomass=fill(0.0, 41)))

    run!(m)

    @test m[:biomass][1] ≈ 3.4722222222222223
    @test m[:biomass][end] ≈ 199.30555555555554

end