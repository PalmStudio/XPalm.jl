@testset "InternodeDimensionModel" begin
    scene = test_scene(
        :Internode,
        InternodeDimensionModel(300000);
        status=Status(potential_height=0.10, potential_radius=0.30, biomass=10.0),
    )
    run!(scene)
    status = test_status(scene, :Internode)
    @test status.height ≈ 0.01056400961258181
    @test status.radius ≈ 0.03169202883774543
end

@testset "FinalPotentialInternodeDimensionModel" begin
    scene = test_scene(
        :Internode,
        FinalPotentialInternodeDimensionModel(2920, 2920, 0.0001, 0.0001, 0.03, 0.30);
        status=Status(initiation_age=1825),
    )
    run!(scene)
    status = test_status(scene, :Internode)
    @test status.final_potential_height ≈ 0.0187875
    @test status.final_potential_radius ≈ 0.1875375
end


@testset "PotentialInternodeDimensionModel" begin
    scene = test_scene(
        :Internode,
        PotentialInternodeDimensionModel(900.0, 150.0, 900.0, 150.0);
        status=Status(TT_since_init=2000, final_potential_height=0.30, final_potential_radius=10.0),
    )
    run!(scene)
    status = test_status(scene, :Internode)
    @test status.potential_height ≈ 0.29980411039873417
    @test status.potential_radius ≈ 9.993470346624472
end
