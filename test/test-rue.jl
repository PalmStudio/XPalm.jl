
aPPFD_radiation = 60.0
@testset "RUE" begin
    scene = test_scene(
        :Plant,
        ConstantRUEModel(4.8);
        status=Status(aPPFD=aPPFD_radiation),
        environment=meteo[1:1, :],
    )
    run!(scene)
    @test test_status(scene, :Plant).carbon_assimilation ≈ aPPFD_radiation / Constants().J_to_umol * 4.8
end

@testset "Multiscale RUE" begin
    scene = test_scene(
        :Plant,
        ConstantRUEModel(4.8);
        status=Status(aPPFD=aPPFD_radiation),
        environment=meteo,
    )
    sim = run!(
        scene;
        steps=nrow(meteo),
        outputs=OutputRequest(:Plant, :carbon_assimilation),
    )
    @test output_values(sim, :carbon_assimilation)[1] ≈ aPPFD_radiation / Constants().J_to_umol * 4.8
end

@testset "Beer+RUE" begin
    leaf_area_plant = 1.0
    plant_area = 10000.0 / 136.0
    scene_leaf_area = leaf_area_plant * plant_area
    scene = Scene(
        Object(:scene; scale=:Scene, kind=:scene, status=Status(lai=2.0)),
        Object(
            :plant;
            scale=:Plant,
            kind=:plant,
            parent=:scene,
            status=Status(leaf_area=leaf_area_plant, scene_leaf_area=scene_leaf_area),
        );
        applications=(
            ModelSpec(Beer(0.5); name=:scene_light) |>
            AppliesTo(One(scale=:Scene)),
            ModelSpec(SceneToPlantLightPartitioning(plant_area); name=:plant_light) |>
            AppliesTo(One(scale=:Plant)) |>
            Inputs(:aPPFD_scene => One(scale=:Scene, var=:aPPFD, within=SceneScope())),
            ModelSpec(ConstantRUEModel(4.8); name=:plant_rue) |>
            AppliesTo(One(scale=:Plant)),
        ),
        environment=meteo,
    )
    sim = run!(
        scene;
        steps=nrow(meteo),
        outputs=OutputRequest(:Plant, :carbon_assimilation),
    )
    values = output_values(sim, :carbon_assimilation)
    @test values[1] ≈ 24.221335070384264
    @test values[end] ≈ 22.30710240739654
end
