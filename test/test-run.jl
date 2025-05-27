
@testset "xpalm" begin
    df = xpalm(meteo, DataFrame; vars=Dict("Scene" => (:lai,)))
    @test only(unique(df.organ)) == "Scene"
    @test df.lai[1] == 0.000272

    # The simulation has randomness, and the version of Julia has an impact even with the same seed
    lai_end = VERSION >= v"1.10" ? 5.058760235616438 : 5.674650301369863
    @test df.lai[end] ≈ lai_end

    # Testing the other method signature, without providing a sink:
    sim = xpalm(meteo; vars=Dict("Scene" => (:lai,)), palm=XPalm.Palm(initiation_age=0, parameters=XPalm.default_parameters()))
    @test only(sim["Scene"][:lai][end]) == df.lai[end]
end