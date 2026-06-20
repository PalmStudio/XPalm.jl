@testset "FinalPotentialAreaModel" begin
    scene = test_scene(
        :Leaf,
        FinalPotentialAreaModel(8 * 365, 0.0015, 12.0);
        status=Status(initiation_age=1825),
    )
    run!(scene)
    @test test_status(scene, :Leaf).final_potential_area ≈ 7.500562499999999
end

@testset "PotentialAreaModel" begin
    model = PotentialAreaModel(560.0, 100.0)
    function potential_area_at(thermal_time)
        scene = test_scene(
            :Leaf,
            model;
            status=Status(TT_since_init=thermal_time, final_potential_area=8.0),
        )
        run!(scene)
        return test_status(scene, :Leaf)
    end
    @test potential_area_at(3000).potential_area ≈ 2.9890383871139807e-6
    @test potential_area_at(5520).potential_area ≈ 7.999756547544795
    @test potential_area_at(1).maturity == false
    @test potential_area_at(9000).maturity == true
end

@testset "LeafAreaModel" begin
    scene = test_scene(
        :Leaf,
        LeafAreaModel(80.0, 0.35, 0.0);
        status=Status(biomass=2000.0),
    )
    run!(scene)
    @test test_status(scene, :Leaf).leaf_area ≈ 8.75
end

@testset "LAIModel" begin
    scene = test_scene(
        :Scene,
        LAIModel(30.0);
        status=Status(leaf_areas=[12.0]),
    )
    run!(scene)
    @test test_status(scene, :Scene).lai == 0.4
end


@testset "LAIModel" begin
    mtg = Palm().mtg
    applications = (
        ModelSpec(LeafBiomass(); name=:leaf_biomass) |>
        AppliesTo(Many(scale=:Leaf)),
        ModelSpec(LeafAreaModel(80.0, 0.35, 0.0); name=:leaf_area) |>
        AppliesTo(Many(scale=:Leaf)),
        ModelSpec(LAIModel(30.0); name=:scene_lai) |>
        AppliesTo(One(scale=:Scene)) |>
        Inputs(:leaf_areas => Many(scale=:Leaf, var=:leaf_area, within=SceneScope())),
    )
    scene = Scene(
        mtg;
        applications=applications,
        environment=meteo,
        status=node -> Status(node=node, carbon_allocation=10.0),
    )
    sim = run!(
        scene;
        steps=nrow(meteo),
        outputs=[
            OutputRequest(:Scene, :lai),
            OutputRequest(:Scene, :leaf_area; name=:scene_leaf_area),
            OutputRequest(:Leaf, :leaf_area; name=:leaf_leaf_area),
        ],
    )
    lai = output_values(sim, :lai)
    @test lai[1] ≈ 0.0010127314814814814
    @test lai[end] ≈ 4.2129629629632985
end
