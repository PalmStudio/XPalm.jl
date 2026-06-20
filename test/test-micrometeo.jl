@testset "ET0_BP" begin
    scene = test_scene(:Scene, ET0_BP(); environment=meteo[1:1, :])
    run!(scene)
    @test test_status(scene, :Scene).ET0 ≈ 0.855813392356407
end

@testset "thermal_time" begin
    scene = test_scene(:Plant, DailyDegreeDays(); environment=meteo)
    sim = run!(
        scene;
        steps=nrow(meteo),
        outputs=[
            OutputRequest(:Plant, :TEff),
            OutputRequest(:Plant, :TT_since_init),
        ],
    )
    teff = output_values(sim, :TEff)
    thermal_time = output_values(sim, :TT_since_init)
    @test teff[1] ≈ 8.996814638030823
    @test teff[end] ≈ 9.608695832784498
    @test thermal_time[10] ≈ 89.3153902056305
    @test thermal_time[end] ≈ 39522.93549866889
end

@testset "thermal_time_ftsw" begin
    scene = test_scene(
        :Plant,
        DegreeDaysFTSW(threshold_ftsw_stress=0.3);
        status=Status(ftsw=0.2),
        environment=meteo,
    )
    sim = run!(
        scene;
        steps=nrow(meteo),
        outputs=OutputRequest(:Plant, :TEff),
    )
    teff = output_values(sim, :TEff)
    @test teff[1] ≈ 5.9978764253538825
    @test teff[end] ≈ 6.405797221856333
end
