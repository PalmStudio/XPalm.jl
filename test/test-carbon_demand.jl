@testset "InternodeCarbonDemandModel" begin
    mtg = Palm().mtg
    applications = (
        ModelSpec(DailyPlantAgeModel(); name=:plant_age, on=One(scale=:Plant)),
        ModelSpec(DailyDegreeDays(); name=:plant_thermal_time, on=One(scale=:Plant)),
        ModelSpec(InitiationAgeFromPlantAge(); name=:internode_initiation_age, on=Many(scale=:Internode), inputs=(:plant_age => One(scale=:Plant, var=:plant_age, within=SelfPlant()))),
        ModelSpec(DailyDegreeDaysSinceInit(); name=:internode_thermal_time, on=Many(scale=:Internode), inputs=(:TEff => One(scale=:Plant, var=:TEff, within=SelfPlant()))),
        ModelSpec(FinalPotentialInternodeDimensionModel(); name=:internode_final_dimensions, on=Many(scale=:Internode)),
        ModelSpec(PotentialInternodeDimensionModel(); name=:internode_potential_dimensions, on=Many(scale=:Internode)),
        ModelSpec(
            InternodeCarbonDemandModel(
                apparent_density=300000.0,
                respiration_cost=1.44,
            );
            name=:internode_carbon_demand,
            on=Many(scale=:Internode),
        ),
    )
    scene = CompositeModel(
        mtg;
        applications=applications,
        environment=meteo,
        status=node -> Status(node=node),
    )
    sim = run!(
        scene;
        steps=nrow(meteo),
        outputs=[
            OutputRequest(:Internode, :carbon_demand),
            OutputRequest(:Internode, :potential_volume),
        ],
    )
    carbon_demand = output_values(sim, :carbon_demand)
    potential_volume = output_values(sim, :potential_volume)
    total_demand = sum(carbon_demand)
    biomass = total_demand / 1.44
    @test total_demand ≈ 3664.353671147133
    @test biomass ≈ potential_volume[end] * 300000.0 ≈ 2544.6900494077313
end


@testset "LeafCarbonDemandModelPotentialArea" begin
    scene = test_scene(
        :Leaf,
        LeafCarbonDemandModelPotentialArea(80.0, 1.44, 0.30);
        status=Status(increment_potential_area=1.0, state=:undetermined),
        environment=meteo[1:2, :],
    )
    sim = run!(
        scene;
        steps=2,
        outputs=OutputRequest(:Leaf, :carbon_demand),
    )
    carbon_demand = output_values(sim, :carbon_demand)
    @test carbon_demand[1] ≈ 384.0
    @test carbon_demand[1] ≈ 1.0 * (80.0 * 1.44) / 0.30

    # Carbon concentration was briefly part of this API. The compatibility
    # constructor must ignore it because construction cost is already per gDM.
    compatibility_model =
        LeafCarbonDemandModelPotentialArea(80.0, 1.44, 0.30, 0.48)
    compatibility_status = Status(
        increment_potential_area=1.0,
        state=:undetermined,
        carbon_demand=0.0,
    )
    PlantSimEngine.run!(compatibility_model, compatibility_status, nothing, nothing)
    @test compatibility_status.carbon_demand ≈ 384.0
end

@testset "LeafCarbonDemandModelArea" begin
    model = XPalm.Models.LeafCarbonDemandModelArea(80.0, 1.44, 0.30)
    status = Status(potential_area=3.0, leaf_area=1.0, carbon_demand=0.0)
    PlantSimEngine.run!(model, status, nothing, nothing)
    @test status.carbon_demand ≈ 768.0
end

@testset "Male carbon demand uses dry-mass construction cost" begin
    scene = test_scene(
        :Male,
        MaleCarbonDemandModel(
            respiration_cost=1.44,
            duration_flowering_male=1800.0,
        );
        status=Status(
            final_potential_biomass=360.0,
            TEff=10.0,
            state=:flowering,
            TT_since_init=100.0,
        ),
    )
    run!(scene)
    @test test_status(scene, :Male).carbon_demand ≈ 2.88
end

@testset "Female component demands use dry-mass construction costs" begin
    scene = test_scene(
        :Female,
        FemaleCarbonDemandModel(
            respiration_cost=1.44,
            respiration_cost_oleosynthesis=3.2,
            TT_flowering=100.0,
            duration_bunch_development=100.0,
            duration_fruit_setting=10.0,
            fraction_period_oleosynthesis=0.8,
            fraction_period_stalk=0.2,
        );
        status=Status(
            final_potential_biomass_non_oil_fruit=4.875,
            final_potential_biomass_oil_fruit=1.625,
            final_potential_biomass_stalk=2100.0,
            fruits_number=100,
            TEff=1.0,
            state=:oleosynthesis,
            TT_since_init=120.0,
        ),
    )
    run!(scene)
    status = test_status(scene, :Female)
    @test status.carbon_demand_non_oil ≈ 7.02
    @test status.carbon_demand_oil ≈ 6.5
    @test status.carbon_demand_stalk ≈ 72.0
    @test status.carbon_demand ≈ 85.52
end
