@testset "CarbonOfferPhotosynthesis" begin
    m = ModelList(biomass=XPalm.CarbonOfferPhotosynthesis(),
        status=(carbon_assimilation=10.0,))

    run!(m, executor=SequentialEx())

    @test m[:carbon_offer][1] ≈ 10.0
end