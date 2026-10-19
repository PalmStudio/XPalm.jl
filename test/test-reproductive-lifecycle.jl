@testset "Leaf pruning removes only the leaf" begin
    for T in (Float32, Float64), rank in (49, 50, 51)
        model = RankLeafPruning(50)
        status = Status(merge(
            PlantSimEngine.outputs_(model),
            (rank=rank, state=:opened, biomass=T(100),
             biomass_leaflets=T(30), biomass_rachis=T(30), biomass_petiole=T(40),
             leaf_area=T(2), reserve=T(10), state_phytomers=[:undetermined]),
        ))
        # A leaf-only operation needs no graph mutation or reproductive context.
        PlantSimEngine.run!(model, status, nothing, nothing, nothing)
        @test status.state_phytomers == [:undetermined]
        @test status.is_pruned == (rank > 50)
        if rank > 50
            @test status.pruning_decision == :pruned_at_rank
            @test status.litter_leaf == 100
            @test status.biomass == status.biomass_leaflets ==
                  status.biomass_rachis == status.biomass_petiole == 0
            @test status.reserve == status.leaf_area == 0
        else
            @test status.biomass == 100
            @test status.leaf_area == 2
        end
    end
end

function lifecycle_female_fixture()
    parameters = XPalm.default_parameters()
    parameters["reproduction"]["sex_ratio"]["random_seed"] = 1
    parameters["reproduction"]["abortion"]["abortion_rate_max"] = 1.0
    parameters["reproduction"]["abortion"]["abortion_rate_ref"] = 1.0
    scene = XPalm.xpalm_scene(
        XPalm.Palm(initiation_age=0, parameters=parameters);
        architecture=false, environment=meteo[1:4, :],
    )
    simulation = run!(scene; steps=1, outputs=:none)
    phytomer = only(model_objects(scene; scale=:Phytomer))
    leaf = only(model_objects(scene; scale=:Leaf))
    inflorescence = parameters["phenology"]["inflorescence"]
    phytomer.status.TT_since_init =
        inflorescence["TT_flowering"] - inflorescence["duration_abortion"]
    phytomer.status.carbon_demand_sex_determination = 1.0
    phytomer.status.carbon_offer_sex_determination = 1.0e12
    PlantSimEngine.continue!(simulation; steps=1)
    female = only(model_objects(scene; scale=:Female))
    (; parameters, scene, simulation, phytomer, leaf, female)
end

@testset "Rank pruning preserves an immature bunch in a compiled palm" begin
    fixture = lifecycle_female_fixture()
    fixture.leaf.status.rank = 51
    PlantSimEngine.continue!(fixture.simulation; steps=1)
    @test fixture.leaf.status.is_pruned
    @test fixture.leaf.status.leaf_area == 0
    @test fixture.phytomer.status.state != :harvested
    @test fixture.female.status.state != :harvested
    @test !fixture.female.status.is_harvested
    @test fixture.female.status.biomass_bunch_harvested == 0
    @test fixture.female.status.fruits_number_harvested == 0
end

@testset "A same-step abortion remains terminal in a compiled palm" begin
    fixture = lifecycle_female_fixture()
    fixture.phytomer.status.TT_since_init =
        fixture.parameters["phenology"]["inflorescence"]["TT_flowering"] + 0.1
    fixture.phytomer.status.carbon_demand_abortion = 1.0
    fixture.phytomer.status.carbon_offer_abortion = 1.0
    PlantSimEngine.continue!(fixture.simulation; steps=1)
    @test fixture.phytomer.status.abortion_calculation_flag
    @test fixture.phytomer.status.state == :aborted
    @test fixture.female.status.state == :aborted
    @test fixture.female.status.biomass_bunch_harvested == 0
    @test fixture.female.status.fruits_number_harvested == 0
    PlantSimEngine.continue!(fixture.simulation; steps=1)
    @test fixture.phytomer.status.state == :aborted
    @test fixture.female.status.state == :aborted
    @test fixture.female.status.biomass_bunch_harvested == 0
end

@testset "Harvest count and mass are one-timestep pulses" begin
    model = BunchHarvest()
    for T in (Float32, Float64)
        status = Status(merge(
            PlantSimEngine.outputs_(model),
            (state=:harvested, biomass=T(100), biomass_stalk=T(20),
             biomass_fruits=T(80), biomass_oil=T(30), biomass_non_oil=T(50),
             fruits_number=4, final_potential_oil_biomass=T(35)),
        ))
        PlantSimEngine.run!(model, status, nothing, nothing)
        @test status.fruits_number_harvested == 4
        @test status.biomass_bunch_harvested == 100
        @test status.biomass_stalk_harvested + status.biomass_fruit_harvested == 100
        @test status.biomass_bunch_harvested_cum == 100
        @test status.biomass == status.fruits_number == 0
        PlantSimEngine.run!(model, status, nothing, nothing)
        @test status.fruits_number_harvested == 0
        @test status.biomass_bunch_harvested == status.biomass_stalk_harvested ==
              status.biomass_fruit_harvested == status.biomass_oil_harvested ==
              status.biomass_oil_harvested_potential == 0
        @test status.biomass_bunch_harvested_cum == 100
        # Even if a terminal state is republished, a removed bunch cannot
        # produce a second harvest pulse or duplicate its cumulative stock.
        status.state = :aborted
        PlantSimEngine.run!(model, status, nothing, nothing)
        @test status.fruits_number_harvested == 0
        @test status.biomass_bunch_harvested == 0
        @test status.biomass_bunch_harvested_cum == 100

        aborted = Status(merge(
            PlantSimEngine.outputs_(model),
            (state=:aborted, biomass=T(10), biomass_stalk=T(10),
             biomass_fruits=T(0), biomass_oil=T(0), fruits_number=0,
             final_potential_oil_biomass=T(0), fruits_number_harvested=7,
             biomass_bunch_harvested=T(99)),
        ))
        PlantSimEngine.run!(model, aborted, nothing, nothing)
        @test aborted.litter == 10
        @test aborted.fruits_number_harvested == 0
        @test aborted.biomass_bunch_harvested == 0
    end
end
