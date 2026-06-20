@testset "InternodeCarbonDemandModel" begin
    mtg = Palm().mtg
    applications = (
        ModelSpec(DailyPlantAgeModel(); name=:plant_age) |>
        AppliesTo(One(scale=:Plant)),
        ModelSpec(DailyDegreeDays(); name=:plant_thermal_time) |>
        AppliesTo(One(scale=:Plant)),
        ModelSpec(InitiationAgeFromPlantAge(); name=:internode_initiation_age) |>
        AppliesTo(Many(scale=:Internode)) |>
        Inputs(:plant_age => One(scale=:Plant, var=:plant_age, within=SelfPlant())),
        ModelSpec(DailyDegreeDaysSinceInit(); name=:internode_thermal_time) |>
        AppliesTo(Many(scale=:Internode)) |>
        Inputs(:TEff => One(scale=:Plant, var=:TEff, within=SelfPlant())),
        ModelSpec(FinalPotentialInternodeDimensionModel(); name=:internode_final_dimensions) |>
        AppliesTo(Many(scale=:Internode)),
        ModelSpec(PotentialInternodeDimensionModel(); name=:internode_potential_dimensions) |>
        AppliesTo(Many(scale=:Internode)),
        ModelSpec(InternodeCarbonDemandModel(300000.0, 1.44); name=:internode_carbon_demand) |>
        AppliesTo(Many(scale=:Internode)),
    )
    scene = Scene(
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
        LeafCarbonDemandModelPotentialArea(80.0, 1.44, 0.35);
        status=Status(increment_potential_area=1.0, state=:undetermined),
        environment=meteo[1:2, :],
    )
    sim = run!(
        scene;
        steps=2,
        outputs=OutputRequest(:Leaf, :carbon_demand),
    )
    carbon_demand = output_values(sim, :carbon_demand)
    @test carbon_demand[1] ≈ 329.14285714285716
    @test carbon_demand[1] ≈ 1.0 * (80.0 * 1.44) / 0.35
end
