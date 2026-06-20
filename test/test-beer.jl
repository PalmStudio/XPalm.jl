@testset "Beer" begin
    scene = test_scene(
        :Scene,
        Beer(0.5);
        status=Status(lai=2.0),
        environment=meteo,
    )
    sim = run!(
        scene;
        steps=nrow(meteo),
        outputs=OutputRequest(:Scene, :aPPFD),
    )
    values = output_values(sim, :aPPFD)
    @test values[1] ≈ 23.060729431595018
    @test values[end] ≈ 21.238220417042122
end
