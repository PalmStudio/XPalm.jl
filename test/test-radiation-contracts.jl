struct InstantaneousGroundPPFDConsumer <:
       XPalm.Models.AbstractLight_InterceptionModel end

PlantSimEngine.inputs_(::InstantaneousGroundPPFDConsumer) = (
    aPPFD=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::InstantaneousGroundPPFDConsumer) = (
    observed_aPPFD=0.0,
)
PlantSimEngine.variable_contracts_(::InstantaneousGroundPPFDConsumer) = (
    aPPFD=PlantSimEngine.VariableContract(
        unit=:micromol_photon,
        basis=:ground_area,
        temporal=:second,
        aggregation=:rate,
        extent=:intensive,
    ),
)

@testset "daily PAR contracts and scale conversion" begin
    ground_daily = PlantSimEngine.VariableContract(
        unit=:mol_photon,
        basis=:ground_area,
        temporal=:day,
        aggregation=:total,
        extent=:intensive,
    )
    plant_daily = PlantSimEngine.VariableContract(
        unit=:mol_photon,
        basis=:plant,
        temporal=:day,
        aggregation=:total,
        extent=:extensive,
    )

    @test PlantSimEngine.variable_contracts(Beer()).aPPFD == ground_daily
    partition_contracts = PlantSimEngine.variable_contracts(
        SceneToPlantLightPartitioning(10.0),
    )
    @test partition_contracts.aPPFD_scene == ground_daily
    @test partition_contracts.aPPFD == plant_daily
    @test PlantSimEngine.variable_contracts(ConstantRUEModel(4.8)).aPPFD ==
          plant_daily
    @test PlantSimEngine.variable_contracts(RUE_FTSW(4.8, 0.3)).aPPFD ==
          plant_daily
    @test PlantSimEngine.variable_contracts(
        FTSW(ini_root_depth=300.0),
    ).aPPFD == ground_daily
    @test PlantSimEngine.variable_contracts(
        FTSW_BP(ini_root_depth=300.0),
    ).aPPFD == ground_daily

    represented_ground_area = 10.0
    plant_leaf_areas = (2.0, 3.0)
    total_leaf_area = sum(plant_leaf_areas)
    daily_environment = meteo[1:1, :]
    @test daily_environment.duration[1] == Day(1)
    @test daily_environment.Ri_PAR_f[1] > 0.0
    scene = CompositeModel(
        Object(
            :scene;
            scale=:Scene,
            kind=:scene,
            status=Status(lai=0.5, leaf_area=total_leaf_area),
        ),
        Object(
            :plant_a;
            scale=:Plant,
            kind=:plant,
            parent=:scene,
            status=Status(leaf_area=plant_leaf_areas[1]),
        ),
        Object(
            :plant_b;
            scale=:Plant,
            kind=:plant,
            parent=:scene,
            status=Status(leaf_area=plant_leaf_areas[2]),
        );
        applications=(
            ModelSpec(
                Beer(0.5);
                name=:scene_light,
                on=One(scale=:Scene),
            ),
            ModelSpec(
                SceneToPlantLightPartitioning(represented_ground_area);
                name=:plant_light,
                on=Many(scale=:Plant),
                inputs=(
                    :aPPFD_scene => One(
                        scale=:Scene,
                        within=SceneScope(),
                        application=:scene_light,
                        var=:aPPFD,
                    ),
                    :scene_leaf_area => One(
                        scale=:Scene,
                        within=SceneScope(),
                        var=:leaf_area,
                        from_status=true,
                    ),
                ),
            ),
            ModelSpec(
                ConstantRUEModel(4.8);
                name=:plant_rue,
                on=Many(scale=:Plant),
            ),
        ),
        environment=daily_environment,
    )
    run!(scene; steps=1, outputs=:none)

    scene_object = PlantSimEngine.model_object(scene, :scene)
    plant_a = PlantSimEngine.model_object(scene, :plant_a)
    plant_b = PlantSimEngine.model_object(scene, :plant_b)
    expected_scene_photons =
        daily_environment.Ri_PAR_f[1] *
        (1.0 - exp(-0.5 * 0.5)) *
        Constants().J_to_umol
    expected_plant_total = expected_scene_photons * represented_ground_area

    @test scene_object.status.aPPFD ≈ expected_scene_photons
    @test plant_a.status.aPPFD ≈
          expected_plant_total * plant_leaf_areas[1] / total_leaf_area
    @test plant_b.status.aPPFD ≈
          expected_plant_total * plant_leaf_areas[2] / total_leaf_area
    @test plant_a.status.aPPFD + plant_b.status.aPPFD ≈ expected_plant_total
    @test plant_a.status.carbon_assimilation ≈
          plant_a.status.aPPFD / Constants().J_to_umol * 4.8
    @test plant_b.status.carbon_assimilation ≈
          plant_b.status.aPPFD / Constants().J_to_umol * 4.8

    for water_model in (
        FTSW(ini_root_depth=300.0),
        FTSW_BP(ini_root_depth=300.0),
    )
        soil_chain = CompositeModel(
            Object(
                :scene;
                scale=:Scene,
                kind=:scene,
                status=Status(lai=0.5),
            ),
            Object(
                :soil;
                scale=:Soil,
                kind=:soil,
                parent=:scene,
                status=Status(ET0=2.5, TEff=10.0),
            );
            applications=(
                ModelSpec(
                    Beer(0.5);
                    name=:scene_light,
                    on=One(scale=:Scene),
                ),
                ModelSpec(
                    RootGrowthFTSW(ini_root_depth=300.0);
                    name=:root_growth,
                    on=One(scale=:Soil),
                ),
                ModelSpec(
                    water_model;
                    name=:soil_water,
                    on=One(scale=:Soil),
                    inputs=(
                        :aPPFD => One(
                            scale=:Scene,
                            within=SceneScope(),
                            application=:scene_light,
                            var=:aPPFD,
                        ),
                    ),
                ),
            ),
            environment=daily_environment,
        )
        run!(soil_chain; steps=1, outputs=:none)
        soil_scene = PlantSimEngine.model_object(soil_chain, :scene)
        soil_object = PlantSimEngine.model_object(soil_chain, :soil)
        intercepted_fraction =
            soil_scene.status.aPPFD /
            (daily_environment.Ri_PAR_f[1] * Constants().J_to_umol)

        @test soil_scene.status.aPPFD ≈ expected_scene_photons
        @test soil_object.status.aPPFD ≈ soil_scene.status.aPPFD
        @test soil_object.status.transpiration ≈ intercepted_fraction * 2.5
    end

    incompatible = CompositeModel(
        Object(
            :scene;
            scale=:Scene,
            kind=:scene,
            status=Status(lai=0.5),
        ),
        Object(:plant; scale=:Plant, kind=:plant, parent=:scene);
        applications=(
            ModelSpec(
                Beer(0.5);
                name=:scene_light,
                on=One(scale=:Scene),
            ),
            ModelSpec(
                ConstantRUEModel(4.8);
                name=:plant_rue,
                on=One(scale=:Plant),
                inputs=(
                    :aPPFD => One(
                        scale=:Scene,
                        within=SceneScope(),
                        application=:scene_light,
                        var=:aPPFD,
                    ),
                ),
            ),
        ),
        environment=daily_environment,
    )
    exception = try
        PlantSimEngine.Advanced.refresh_bindings!(incompatible)
        nothing
    catch error
        error
    end
    @test exception isa ErrorException
    if exception isa Exception
        message = sprint(showerror, exception)
        @test occursin("Incompatible variable contracts", message)
        @test occursin(
            "basis producer=:ground_area, consumer=:plant",
            message,
        )
        @test occursin(
            "extent producer=:intensive, consumer=:extensive",
            message,
        )
    end

    instantaneous_mismatch = CompositeModel(
        Object(
            :scene;
            scale=:Scene,
            kind=:scene,
            status=Status(lai=0.5),
        );
        applications=(
            ModelSpec(
                Beer(0.5);
                name=:scene_light,
                on=One(scale=:Scene),
            ),
            ModelSpec(
                InstantaneousGroundPPFDConsumer();
                name=:instantaneous_consumer,
                on=One(scale=:Scene),
            ),
        ),
        environment=daily_environment,
    )
    exception = try
        PlantSimEngine.Advanced.refresh_bindings!(instantaneous_mismatch)
        nothing
    catch error
        error
    end
    @test exception isa ErrorException
    if exception isa Exception
        message = sprint(showerror, exception)
        @test occursin(
            "unit producer=:mol_photon, consumer=:micromol_photon",
            message,
        )
        @test occursin(
            "temporal producer=:day, consumer=:second",
            message,
        )
        @test occursin(
            "aggregation producer=:total, consumer=:rate",
            message,
        )
    end
end
