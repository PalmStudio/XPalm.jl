@testset "CarbonOfferRm" begin
    m = ModelList(
        biomass=CarbonOfferRm(),
        status=(carbon_assimilation=10.0, Rm=2.0)
    )
    outputs = run!(m, executor=SequentialEx())
    @test outputs[:carbon_offer_after_rm][1] == 8.0
end