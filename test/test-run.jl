
@testset "xpalm" begin
    df = xpalm(meteo, DataFrame; vars=Dict("Scene" => (:lai,)))
    @test only(keys(df)) == "Scene"
    @test df["Scene"].lai[1] == 0.000272

    # The simulation has randomness, and the version of Julia has an impact even with the same seed
    lai_end = VERSION >= v"1.10" ? 5.058760235616438 : 5.674650301369863
    @test df["Scene"].lai[end] ≈ lai_end
end