
@testset "xpalm" begin
    simulation_meteo = meteo[1:3, :]
    df = xpalm(simulation_meteo, DataFrame; vars=Dict(:Scene => (:lai,)))
    @test only(keys(df)) == :Scene
    @test nrow(df[:Scene]) == nrow(simulation_meteo)
    @test df[:Scene].lai[1] == 0.000272
    @test all(isfinite, df[:Scene].lai)

    # Testing the other method signature, without providing a sink:
    sim = xpalm(
        simulation_meteo;
        vars=Dict(:Scene => (:lai,)),
        palm=XPalm.Palm(initiation_age=0, parameters=XPalm.default_parameters()),
    )
    lai_rows = collect_outputs(sim, :Scene__lai; sink=nothing)
    @test last(lai_rows).value == df[:Scene].lai[end]
end

@testset "default organ biomass is structural dry mass" begin
    parameters = XPalm.default_parameters()
    palm = XPalm.Palm(initiation_age=0, parameters=parameters)
    applications = XPalm.model_applications(palm; architecture=false)

    leaf_biomass = only(
        application for application in applications
        if PlantSimEngine.application_name(application) == :Leaf__biomass
    ).model
    @test leaf_biomass.initial_biomass ≈
          parameters["dimensions"]["leaf"]["leaf_area_first_leaf"] *
          parameters["mass_and_dimensions"]["leaf"]["lma_min"] /
          parameters["biomass"]["leaf"]["leaflets_biomass_contribution"]

    internode_biomass = only(
        application for application in applications
        if PlantSimEngine.application_name(application) == :Internode__biomass
    ).model
    @test internode_biomass.initial_biomass ≈
          π * parameters["dimensions"]["internode"]["min_radius"]^2 *
          parameters["dimensions"]["internode"]["min_height"] *
          parameters["carbon_demand"]["internode"]["apparent_density"]
end

@testset "emission requests are one-timestep pulses" begin
    phyllochron = PhyllochronModel(
        age_palm_maturity=1,
        production_speed_initial=0.1,
        production_speed_mature=0.1,
    )
    phyllochron_status = Status(
        plant_age=1.0,
        TEff=1.0,
        newPhytomerEmergence=0.95,
        production_speed=-Inf,
        emit_phytomer=false,
    )
    PlantSimEngine.run!(
        phyllochron,
        phyllochron_status,
        nothing,
        nothing,
    )
    @test phyllochron_status.emit_phytomer
    @test phyllochron_status.newPhytomerEmergence ≈ 0.05

    PlantSimEngine.run!(
        phyllochron,
        phyllochron_status,
        nothing,
        nothing,
    )
    @test !phyllochron_status.emit_phytomer
    @test phyllochron_status.newPhytomerEmergence ≈ 0.15

    sex_determination = SexDetermination(
        TT_flowering=1.0,
        duration_abortion=0.0,
        duration_sex_determination=1.0,
        sex_ratio_min=0.89,
        sex_ratio_ref=0.90,
        random_seed=1,
    )
    sex_status = Status(
        TT_since_init=2.0,
        carbon_offer_plant=0.0,
        carbon_demand_plant=0.0,
        sex=:undetermined,
        state=:undetermined,
        carbon_demand_sex_determination=1.0,
        carbon_offer_sex_determination=100.0,
        emit_reproductive_organ=false,
    )
    PlantSimEngine.run!(
        sex_determination,
        sex_status,
        nothing,
        nothing,
    )
    determined_sex = sex_status.sex
    @test determined_sex in (:Male, :Female)
    @test sex_status.emit_reproductive_organ

    PlantSimEngine.run!(
        sex_determination,
        sex_status,
        nothing,
        nothing,
    )
    @test sex_status.sex == determined_sex
    @test !sex_status.emit_reproductive_organ
end

function xpalm_test_reproductive_initializer_scene(expected_sex)
    parameters = XPalm.default_parameters()
    inflorescence = parameters["phenology"]["inflorescence"]
    inflorescence["TT_flowering"] = 1000.0
    inflorescence["duration_abortion"] = 500.0
    inflorescence["duration_sex_determination"] = 1.0

    sex_ratio = parameters["reproduction"]["sex_ratio"]
    sex_ratio["random_seed"] = 1
    if expected_sex == :Female
        sex_ratio["sex_ratio_min"] = 0.89
        sex_ratio["sex_ratio_ref"] = 0.90
    else
        sex_ratio["sex_ratio_min"] = 0.01
        sex_ratio["sex_ratio_ref"] = 0.02
    end

    palm = XPalm.Palm(initiation_age=0, parameters=parameters)
    plant = only(
        MultiScaleTreeGraph.descendants(
            palm.mtg;
            symbol=:Plant,
            self=true,
        ),
    )
    plant[:carbon_offer_after_rm] = 0.0
    plant[:carbon_demand] = 0.0
    phytomer = only(
        MultiScaleTreeGraph.descendants(
            palm.mtg;
            symbol=:Phytomer,
            self=true,
        ),
    )
    phytomer[:carbon_demand_sex_determination] = 1.0
    phytomer[:carbon_offer_sex_determination] =
        expected_sex == :Female ? 100.0 : 0.0
    phytomer[:TT_since_init] = 501.0

    return XPalm.xpalm_scene(
        palm;
        architecture=false,
        environment=meteo[1:2, :],
    )
end

@testset "scheduled respiration initializes newborn organs" begin
    palm = XPalm.Palm(
        initiation_age=0,
        parameters=XPalm.default_parameters(),
    )
    applications = XPalm.model_applications(palm; architecture=false)
    application_names = PlantSimEngine.application_name.(applications)
    @test all(
        name -> !endswith(string(name), "__initial_maintenance_respiration"),
        application_names,
    )

    for producer_name in (
        :Plant__phyllochron,
        :Phytomer__sex_determination,
    )
        producer = only(
            application for application in applications
            if PlantSimEngine.application_name(application) == producer_name
        )
        @test isempty(propertynames(PlantSimEngine.model_calls(producer)))
    end

    expected_initializers = (
        (
            :Plant__phytomer_emission,
            :internode_initial_maintenance_respiration,
            :Internode__maintenance_respiration,
        ),
        (
            :Plant__phytomer_emission,
            :leaf_initial_maintenance_respiration,
            :Leaf__maintenance_respiration,
        ),
        (
            :Phytomer__reproductive_organ_emission,
            :male_initial_maintenance_respiration,
            :Male__maintenance_respiration,
        ),
        (
            :Phytomer__reproductive_organ_emission,
            :female_initial_maintenance_respiration,
            :Female__maintenance_respiration,
        ),
    )
    for (creator_name, binding_name, target_name) in expected_initializers
        creator = only(
            application for application in applications
            if PlantSimEngine.application_name(application) == creator_name
        )
        binding = getproperty(PlantSimEngine.model_calls(creator), binding_name)
        @test binding isa PlantSimEngine.Initializer
        @test PlantSimEngine.object_address(binding).application == target_name
    end

    schedule_scene = XPalm.xpalm_scene(
        palm;
        architecture=false,
        environment=meteo[1:2, :],
    )
    compiled = PlantSimEngine.Advanced.refresh_bindings!(schedule_scene)
    schedule = Dict(
        row.application_id => row
        for row in PlantSimEngine.Diagnostics.explain_schedule(compiled)
    )
    canonical_state_bindings = [
        row for row in PlantSimEngine.Diagnostics.explain_bindings(compiled)
        if row.application_id in (
            :Phytomer__sex_determination,
            :Phytomer__reproductive_organ_emission,
        ) && row.input == :state
    ]
    @test length(canonical_state_bindings) == 2
    for binding in canonical_state_bindings
        @test isempty(binding.source_application_ids)
        @test binding.carrier_kind == :ref
        @test binding.carrier_hint != :temporal_stream
    end
    for creator_name in (
        :Plant__phytomer_emission,
        :Phytomer__reproductive_organ_emission,
    )
        @test schedule[creator_name].root_scheduled
        @test !schedule[creator_name].manual_call_only
    end
    @test schedule[:Plant__phyllochron].execution_index <
          schedule[:Plant__phytomer_emission].execution_index <
          schedule[:Plant__leaf_area].execution_index
    @test schedule[:Phytomer__sex_determination].execution_index <
          schedule[:Phytomer__reproductive_organ_emission].execution_index <
          schedule[:Phytomer__state].execution_index
    for (target_name, creator_name) in (
        (:Internode__maintenance_respiration, :Plant__phytomer_emission),
        (:Leaf__maintenance_respiration, :Plant__phytomer_emission),
        (:Male__maintenance_respiration, :Phytomer__reproductive_organ_emission),
        (:Female__maintenance_respiration, :Phytomer__reproductive_organ_emission),
    )
        @test schedule[target_name].execution_index <
              schedule[creator_name].execution_index <
              schedule[:Plant__maintenance_respiration].execution_index
    end

    for expected_sex in (:Male, :Female)
        scene = xpalm_test_reproductive_initializer_scene(expected_sex)
        @test isempty(model_objects(scene; scale=expected_sex))
        simulation = run!(scene; steps=1, outputs=:none)

        emitted = model_objects(scene; scale=expected_sex)
        @test length(emitted) == 1
        organ = only(emitted)
        @test organ.status.sex == expected_sex
        @test isfinite(organ.status.biomass)
        @test isfinite(organ.status.Rm)
        @test organ.status.Rm >= 0.0
        node = PlantSimEngine.source_node(scene, organ)
        @test MultiScaleTreeGraph.symbol(node) == expected_sex
        @test !haskey(
            MultiScaleTreeGraph.node_attributes(node),
            :plantsimengine_status,
        )
        other_sex = expected_sex == :Male ? :Female : :Male
        @test isempty(model_objects(scene; scale=other_sex))

        emitted_ids = Set(organ.id for organ in emitted)
        PlantSimEngine.continue!(simulation; steps=1)
        @test Set(
            organ.id for organ in model_objects(scene)
            if organ.scale in (:Male, :Female)
        ) == emitted_ids
    end
end

@testset "late canonical harvest blocks reproductive emission" begin
    parameters = XPalm.default_parameters()
    inflorescence = parameters["phenology"]["inflorescence"]
    scene = XPalm.xpalm_scene(
        XPalm.Palm(initiation_age=0, parameters=parameters);
        architecture=false,
        environment=meteo[1:2, :],
    )
    simulation = run!(scene; steps=1, outputs=:none)
    phytomer = only(model_objects(scene; scale=:Phytomer))
    phytomer.status.state = :harvested
    phytomer.status.sex = :undetermined
    phytomer.status.TT_since_init =
        inflorescence["TT_flowering"] -
        inflorescence["duration_abortion"]
    phytomer.status.carbon_demand_sex_determination = 1.0
    phytomer.status.carbon_offer_sex_determination = 1.0e12

    PlantSimEngine.continue!(simulation; steps=1)
    @test phytomer.status.state == :harvested
    @test phytomer.status.sex == :undetermined
    @test !phytomer.status.emit_reproductive_organ
    @test isempty(
        organ for organ in model_objects(scene)
        if organ.scale in (:Male, :Female)
    )
end

@testset "same-step reproductive emissions preserve RNG order" begin
    parameters = XPalm.default_parameters()
    random_seed = parameters["reproduction"]["sex_ratio"]["random_seed"]
    inflorescence = parameters["phenology"]["inflorescence"]
    scene = XPalm.xpalm_scene(
        XPalm.Palm(initiation_age=0, parameters=parameters);
        architecture=false,
        environment=meteo[1:14, :],
    )
    simulation = run!(scene; steps=12, outputs=:none)
    @test isempty(
        organ for organ in model_objects(scene)
        if organ.scale in (:Male, :Female)
    )

    phytomers = sort(
        model_objects(scene; scale=:Phytomer);
        by=object -> object.id.value,
    )
    @test length(phytomers) >= 2
    transition_thermal_time =
        inflorescence["TT_flowering"] -
        inflorescence["duration_abortion"]
    for phytomer in phytomers
        phytomer.status.TT_since_init = transition_thermal_time
        phytomer.status.sex = :undetermined
        phytomer.status.state = :undetermined
        phytomer.status.carbon_demand_sex_determination = 1.0
        phytomer.status.carbon_offer_sex_determination = 1.0e12
        phytomer.status.emit_reproductive_organ = false
    end

    expected_rng = MersenneTwister(random_seed)
    expected_sexes = [
        rand(expected_rng) < 0.9 ? :Female : :Male
        for _ in phytomers
    ]
    PlantSimEngine.continue!(simulation; steps=1)

    emitted = sort(
        [
            organ for organ in model_objects(scene)
            if organ.scale in (:Male, :Female)
        ];
        by=object -> object.id.value,
    )
    @test length(emitted) == length(phytomers)
    @test getproperty.(getproperty.(emitted, :status), :sex) == expected_sexes
    @test all(organ -> isfinite(organ.status.Rm), emitted)

    emitted_ids = Set(organ.id for organ in emitted)
    PlantSimEngine.continue!(simulation; steps=1)
    @test Set(
        organ.id for organ in model_objects(scene)
        if organ.scale in (:Male, :Female)
    ) == emitted_ids
end
