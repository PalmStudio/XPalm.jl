
@testset "xpalm" begin
    df = xpalm(meteo, DataFrame; vars=Dict(:Scene => (:lai,)))
    @test only(keys(df)) == :Scene
    @test df[:Scene].lai[1] == 0.000272

    # The simulation has randomness, and the version of Julia has an impact even with the same seed

    @test df[:Scene].lai[end] ≈ 5.058760235616438 ||
          df[:Scene].lai[end] ≈ 5.514191353424657

    # Testing the other method signature, without providing a sink:
    sim = xpalm(meteo; vars=Dict(:Scene => (:lai,)), palm=XPalm.Palm(initiation_age=0, parameters=XPalm.default_parameters()))
    @test only(sim[:Scene][end].lai) == df[:Scene].lai[end]
end

@testset "male Rm initialized at emission" begin
    out = xpalm(meteo, DataFrame; vars=Dict(:Male => (:Rm,)))
    male = out[:Male]
    first_rm_per_node = [first(g.Rm) for g in groupby(male, :node)]
    @test all(isfinite, first_rm_per_node)
end
