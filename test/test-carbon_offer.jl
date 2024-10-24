@testset "CarbonOfferRm" begin
    m = ModelList(biomass=XPalm.CarbonOfferRm(),
        status=(carbon_assimilation=10.0, Rm=2.0))

    run!(m, executor=SequentialEx())

    @test m[:carbon_offer_after_rm][1] == 8.0
end

@testset "CarbonOfferPhotosynthesis" begin
    m = ModelList(
        XPalm.CarbonOfferPhotosynthesis(),
        status=(carbon_assimilation=10.0,)
    )

    run!(m, executor=SequentialEx())

    @test m[:carbon_offer][1] == 10.0
end