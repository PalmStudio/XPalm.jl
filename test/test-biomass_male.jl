@testset "MaleBiomass" begin
    m = ModelList(biomass=XPalm.MaleBiomass(1.44),
        status=(carbon_allocation=fill(15.0, 4), state=["undetermined", "undetermined", "Senescent", "Senescent"],))

    run!(m, executor=SequentialEx())

    @test m[:biomass][1] ≈ 10.416666666666668
    @test m[:biomass][end] ≈ 0.0
    @test m[:litter_male][end] ≈ 31.250000000000004

end


