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
        LeafAreaModel(80.0, 0.30, 0.0);
        status=Status(biomass=2000.0),
    )
    run!(scene)
    @test test_status(scene, :Leaf).leaf_area ≈ 7.5
end

@testset "LeafBiomass compartments" begin
    scene = test_scene(
        :Leaf,
        LeafBiomass(
            initial_biomass=100.0,
            respiration_cost=1.44,
            leaflets_biomass_contribution=0.30,
            rachis_biomass_contribution=0.30,
            petiole_biomass_contribution=0.40,
        );
        status=Status(carbon_allocation=144.0),
    )
    run!(scene)
    status = test_status(scene, :Leaf)
    @test status.biomass ≈ 200.0
    @test status.biomass_leaflets ≈ 60.0
    @test status.biomass_rachis ≈ 60.0
    @test status.biomass_petiole ≈ 80.0
    @test status.biomass ≈
          status.biomass_leaflets + status.biomass_rachis + status.biomass_petiole
    @test_throws ArgumentError LeafBiomass(
        leaflets_biomass_contribution=0.30,
        rachis_biomass_contribution=0.30,
        petiole_biomass_contribution=0.30,
    )
end

@testset "PotentialReserveLeaf CH2O-equivalent units" begin
    scene = test_scene(
        :Leaf,
        PotentialReserveLeaf(80.0, 200.0, 0.30, 0.48);
        status=Status(leaf_area=2.0, reserve=10.0, state=:opened),
    )
    run!(scene)
    @test test_status(scene, :Leaf).potential_reserve ≈ 790.0
end

@testset "PotentialReserveInternode CH2O-equivalent units" begin
    scene = test_scene(
        :Internode,
        PotentialReserveInternode(nsc_max=0.30, carbon_concentration=0.50);
        status=Status(biomass=1000.0, reserve=20.0),
    )
    run!(scene)
    @test test_status(scene, :Internode).potential_reserve ≈ 280.0
    @test PotentialReserveInternode(0.30, 0.50).nsc_max == 0.30
end

@testset "Leaf pruning clears biomass compartments" begin
    parameters = XPalm.default_parameters()
    parameters["management"]["rank_leaf_pruning"] = 0
    scene = XPalm.xpalm_scene(
        Palm(initiation_age=0, parameters=parameters);
        architecture=false,
        environment=meteo[1:1, :],
    )
    run!(scene; steps=1, outputs=:none)
    status = only(model_objects(scene; scale=:Leaf)).status
    @test status.is_pruned
    @test status.litter_leaf > 0.0
    @test status.biomass == 0.0
    @test status.biomass_leaflets == 0.0
    @test status.biomass_rachis == 0.0
    @test status.biomass_petiole == 0.0
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
        ModelSpec(LeafBiomass(); name=:leaf_biomass, on=Many(scale=:Leaf)),
        ModelSpec(LeafAreaModel(80.0, 0.30, 0.0); name=:leaf_area, on=Many(scale=:Leaf)),
        ModelSpec(LAIModel(30.0); name=:scene_lai, on=One(scale=:Scene), inputs=(:leaf_areas => Many(scale=:Leaf, var=:leaf_area, within=SceneScope()))),
    )
    scene = CompositeModel(
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
    @test lai[1] ≈ 0.0008680555555555555
    @test lai[end] ≈ 3.611111111111399
end
