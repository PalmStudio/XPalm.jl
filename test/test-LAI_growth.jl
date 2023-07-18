@testset "LAIGrowth" begin
    m = ModelList(lai_dynamic=XPalm.LAIGrowth(5.0, 3 * 10^-5, 0.5),
        status=(ftsw=[0.01:0.001:1;], TEff=fill(9.0, 991), LAI=fill(0.0, 991)))

    run!(m, executor=SequentialEx())

    @test m[:LAI][100] ≈ 0.0031595400000000006
    @test m[:LAI][900] ≈ 0.1777760999999999
end