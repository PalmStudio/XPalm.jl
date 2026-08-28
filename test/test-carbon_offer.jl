@testset "CarbonOfferRm" begin
    scene = test_scene(
        :Plant,
        CarbonOfferRm();
        status=Status(carbon_assimilation=10.0, Rm=2.0),
    )
    run!(scene)
    @test test_status(scene, :Plant).carbon_offer_after_rm == 8.0
end
