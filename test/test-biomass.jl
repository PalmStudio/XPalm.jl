@testset "InternodeBiomass" begin
    scene = test_scene(
        :Internode,
        InternodeBiomass();
        status=Status(carbon_allocation=10.0, biomass=0.0),
    )
    run!(scene)
    @test test_status(scene, :Internode).biomass ≈ 10.0 / 1.44
end

@testset "MaleBiomass" begin
    @testset "Continuous growth" begin
        scene = test_scene(
            :Male,
            MaleBiomass();
            status=Status(carbon_allocation=10.0, state=:undetermined),
            environment=meteo,
        )
        sim = run!(
            scene;
            steps=nrow(meteo),
            outputs=[
                OutputRequest(:Male, :biomass),
                OutputRequest(:Male, :litter_male),
            ],
        )
        biomass = output_values(sim, :biomass)
        litter = output_values(sim, :litter_male)
        @test biomass[1] ≈ 6.944444444444445
        @test biomass[end] ≈ 28888.888888891193
        @test litter[end] ≈ 0.0 # no senescence
    end

    @testset "Harvested" begin
        scene = test_scene(
            :Male,
            MaleBiomass();
            status=Status(carbon_allocation=0.0, state=:harvested, biomass=10.0),
            environment=meteo,
        )
        sim = run!(
            scene;
            steps=nrow(meteo),
            outputs=[
                OutputRequest(:Male, :biomass),
                OutputRequest(:Male, :litter_male),
            ],
        )
        biomass = output_values(sim, :biomass)
        litter = output_values(sim, :litter_male)
        @test biomass == zeros(length(biomass))
        @test litter[1] == 10.0
        @test litter[2:end] == zeros(length(biomass) - 1)
    end

    @testset "Aborted" begin
        scene = test_scene(
            :Male,
            MaleBiomass();
            status=Status(carbon_allocation=10.0, state=:aborted, biomass=0.0),
            environment=meteo,
        )
        sim = run!(
            scene;
            steps=nrow(meteo),
            outputs=[
                OutputRequest(:Male, :biomass),
                OutputRequest(:Male, :litter_male),
            ],
        )
        biomass = output_values(sim, :biomass)
        litter = output_values(sim, :litter_male)
        @test biomass == zeros(length(biomass))
        @test litter == zeros(length(biomass))
    end
end


@testset "FemaleBiomass" begin
    scene = test_scene(
        :Female,
        FemaleBiomass();
        status=Status(carbon_allocation=15.0, state=:undetermined, biomass=10.0, carbon_demand_stalk=2.0, carbon_demand_non_oil=1.0, carbon_demand_oil=3.0, carbon_demand=6.0),
        environment=meteo[1:1, :],
    )
    run!(scene)
    status = test_status(scene, :Female)
    @test status.biomass ≈ 7.552083333333333
    @test status.biomass_stalk ≈ 3.4722222222222223
    @test status.biomass_fruits ≈ 4.079861111111111
    @test status.biomass_non_oil ≈ 1.7361111111111112
    @test status.biomass_oil ≈ 2.34375
    @test status.biomass ≈ status.biomass_stalk + status.biomass_fruits
end


@testset "MaleFinalPotentialBiomass keeps the initialized sex" begin
    source = Status(initiation_age=50.0, sex=:Male)
    sex_reference = PlantSimEngine.refvalue(source, :sex)
    scene = test_scene(:Male, MaleFinalPotentialBiomass(1000.0, 100.0, 0.1);
        status=source)
    run!(scene)
    status = test_status(scene, :Male)
    @test status.sex === :Male
    @test PlantSimEngine.refvalue(status, :sex) === sex_reference
    @test status.final_potential_biomass ≈ 550.0
end

@testset "FemaleFinalPotentialFruits keeps the initialized sex" begin
    source = Status(initiation_age=6500.0, sex=:Female)
    sex_reference = PlantSimEngine.refvalue(source, :sex)
    scene = test_scene(:Female, FemaleFinalPotentialFruits(); status=source)
    run!(scene)
    status = test_status(scene, :Female)
    @test status.sex === :Female
    @test PlantSimEngine.refvalue(status, :sex) === sex_reference
    @test status.potential_fruits_number == 2000
    @test status.final_potential_fruit_biomass ≈ 6.5
    @test status.final_potential_biomass_stalk ≈ 2100.0
    @test status.final_potential_oil_biomass ≈ 3250.0
    @test status.final_potential_non_oil_biomass ≈ 9750.0
end
