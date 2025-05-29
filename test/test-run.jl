
@testset "xpalm" begin
    df = xpalm(meteo, DataFrame; vars=Dict("Scene" => (:lai,)))
    @test only(keys(df)) == "Scene"
    @test df["Scene"].lai[1] == 0.000272

    # The simulation has randomness, and the version of Julia has an impact even with the same seed

    lai_end = VERSION >= v"1.10" ? 5.058760235616438 : 5.514191353424657
    @test df["Scene"].lai[end] ≈ lai_end

    # Testing the other method signature, without providing a sink:
    sim = xpalm(meteo; vars=Dict("Scene" => (:lai,)), palm=XPalm.Palm(initiation_age=0, parameters=XPalm.default_parameters()))
    @test only(sim["Scene"][end].lai) == df["Scene"].lai[end]
end