@testset "FinalPotentialAreaModel" begin
    m = ModelList(
        leaf_final_potential_area=XPalm.FinalPotentialAreaModel(8 * 365, 0.0015, 12.0),
        status=(initiation_age=1825,)
    )
    run!(m)
    @test m[:final_potential_area][1] ≈ 7.500562499999999
end

@testset "PotentialAreaModel" begin
    m = ModelList(
        leaf_potential_area=XPalm.PotentialAreaModel(560.0, 100.0),
        status=(TT_since_init=[1:1:10000;], final_potential_area=fill(8.0, 10000),)
    )
    run!(m)
    @test m[:potential_area][3000] ≈ 2.9890383871139807e-6
    @test m[:potential_area][5520] ≈ 7.999756547544795
    @test m[:maturity][1] ≈ false
    @test m[:maturity][9000] ≈ true
end

@testset "LeafAreaModel" begin
    m = ModelList(
        leaf_area=XPalm.LeafAreaModel(80.0, 0.35, 0.0),
        status=(biomass=2000.0,)
    )
    run!(m)
    @test m[:leaf_area][1] ≈ 8.75
end

@testset "LAIGrowth" begin
    m = ModelList(
        lai_dynamic=XPalm.LAIGrowth(LAI_max=5.0, LAI_growth_rate=3 * 10^-5, TRESH_FTSW_SLOW_LAI=0.5),
        status=(ftsw=[0.01:0.001:1;], TEff=fill(9.0, 991), LAI=fill(0.0, 991))
    )

    run!(m, executor=SequentialEx())
    @test m[:LAI][100] ≈ 0.0031595400000000006
    @test m[:LAI][900] ≈ 0.1777760999999999
end