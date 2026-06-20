
@testset "xpalm" begin
    simulation_meteo = meteo[1:3, :]
    df = xpalm(simulation_meteo, DataFrame; vars=Dict(:Scene => (:lai,)))
    @test only(keys(df)) == :Scene
    @test nrow(df[:Scene]) == nrow(simulation_meteo)
    @test df[:Scene].lai[1] == 0.000272
    @test all(isfinite, df[:Scene].lai)

    # Testing the other method signature, without providing a sink:
    sim = xpalm(
        simulation_meteo;
        vars=Dict(:Scene => (:lai,)),
        palm=XPalm.Palm(initiation_age=0, parameters=XPalm.default_parameters()),
    )
    lai_rows = collect_outputs(sim, :Scene__lai; sink=nothing)
    @test last(lai_rows).value == df[:Scene].lai[end]
end

@testset "male Rm initialized at emission" begin
    out = xpalm(meteo[1:3, :], DataFrame; vars=Dict(:Male => (:Rm,)))
    male = out[:Male]
    if nrow(male) > 0
        first_rm_per_node = [first(g.Rm) for g in groupby(male, :node)]
        @test all(isfinite, first_rm_per_node)
    else
        @test ncol(male) == 0
    end
end
