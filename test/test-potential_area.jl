@testset "PotentialAreaModel" begin
    m = ModelList(leaf_potential_area=XPalm.PotentialAreaModel(560.0, 100.0),
        status=(TT_since_init=[1:1:10000;], final_potential_area=fill(8.0, 10000),))

    run!(m)

    @test m[:potential_area][3000] ≈ 2.9890383871139807e-6
    @test m[:potential_area][5520] ≈ 7.999756547544795
    @test m[:maturity][1] ≈ false
    @test m[:maturity][9000] ≈ true
end