@testset "LeafAreaModel" begin
    m = ModelList(leaf_area=XPalm.LeafAreaModel(80.0, 0.35),
        status=(biomass=2000.0,))

    run!(m)

    @test m[:leaf_area][1] ≈ 8.75
end