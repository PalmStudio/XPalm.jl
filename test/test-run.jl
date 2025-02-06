
@testset "xpalm" begin
    df = xpalm(meteo, DataFrame; vars=Dict("Scene" => (:lai,)))
    @test only(unique(df.organ)) == "Scene"
    @test df.lai[1] == 0.000272

    # The simulation has randomness, and the version of Julia has an impact even with the same seed
    lai_end = VERSION >= v"1.10" ? 5.674650301369863 : 5.058760235616438
    @test df.lai[end] ≈ lai_end
end