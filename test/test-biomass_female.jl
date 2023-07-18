@testset "FemaleBiomass" begin
    m = ModelList(biomass=XPalm.FemaleBiomass(1.44, 3.2),
        status=(carbon_allocation=fill(15.0, 10), biomass_stalk=fill(5.0, 10), biomass_fruits=fill(4.0, 10), carbon_demand_stalk=fill(2.0, 10), carbon_demand_non_oil=fill(1.0, 10), carbon_demand_oil=fill(3.0, 10), state=fill("Oleosynthesis", 10),))

    ### problem du to 'st' to get prev value!!
    run!(m, executor=SequentialEx())

    @test m[:biomass][1] ≈ 11.944444444444445
    @test m[:biomass][2] ≈ 18.88888888888889
end


