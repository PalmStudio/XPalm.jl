@testset "FemaleBiomass" begin
    m = ModelList(biomass=XPalm.FemaleBiomass(1.44, 3.2),
        status=(carbon_allocation=fill(15.0, 15), carbon_demand_stalk=fill(2.0, 15), carbon_demand_non_oil=fill(1.0, 15), carbon_demand_oil=fill(3.0, 15), state=[fill("Flowering", 5); fill("Oleosynthesis", 5); fill("Harvested", 5)],))
    run!(m, executor=SequentialEx())

    @test m[:biomass_fruits][5] ≈ 20.399305555555554
    @test m[:biomass_stalk][10] ≈ 34.72222222222222
    @test m[:biomass_stalk][end] ≈ -Inf

end


