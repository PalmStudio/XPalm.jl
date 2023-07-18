@testset "FinalPotentialAreaModel" begin
    m = ModelList(leaf_final_potential_area=XPalm.FinalPotentialAreaModel(8 * 365, 0.0015, 12.0),
        status=(initiation_age=1825,))

    run!(m)

    @test m[:final_potential_area][1] ≈ 7.500562499999999

end