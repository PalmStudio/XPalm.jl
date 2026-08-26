struct XPalmTestAllocationInputs <: PlantSimEngine.AbstractModel end

PlantSimEngine.process(::XPalmTestAllocationInputs) =
    :xpalm_test_allocation_inputs
PlantSimEngine.inputs_(::XPalmTestAllocationInputs) = (
    carbon_demand_seed=PlantSimEngine.Required(Real),
    potential_reserve_seed=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::XPalmTestAllocationInputs) = (
    carbon_demand=0.0,
    potential_reserve=0.0,
)

function PlantSimEngine.run!(
    ::XPalmTestAllocationInputs,
    status,
    environment,
    constants,
    context,
)
    status.carbon_demand = status.carbon_demand_seed
    status.potential_reserve = status.potential_reserve_seed
    return nothing
end

function xpalm_test_allocation_applications(; mismatched_allocations=false)
    organ_scales = (:Leaf, :Internode, :Male, :Female)
    allocation_scales =
        mismatched_allocations ? :Leaf : organ_scales
    return (
        ModelSpec(
            XPalmTestAllocationInputs();
            name=:xpalm_test_allocation_inputs,
            on=Many(scale=organ_scales),
        ),
        ModelSpec(
            OrgansCarbonAllocationModel(; cost_reserve_mobilization=2.0);
            name=:xpalm_test_carbon_allocation,
            on=Many(scale=:Plant),
            inputs=(
                :carbon_demand_organs => Many(
                    scale=organ_scales,
                    within=PlantSimEngine.Subtree(),
                    application=:xpalm_test_allocation_inputs,
                    var=:carbon_demand,
                ),
                PreviousTimeStep(:previous_reserve_organs) => Many(
                    scale=(:Internode, :Leaf),
                    within=PlantSimEngine.Subtree(),
                    var=:reserve,
                ),
            ),
            outputs_to=(
                carbon_allocation=PlantSimEngine.OutputTo(
                    Many(
                        scale=allocation_scales,
                        within=PlantSimEngine.Subtree(),
                    );
                    vars=(
                        carbon_allocation=PlantSimEngine.Default(0.0),
                    ),
                ),
                reserve=PlantSimEngine.OutputTo(
                    Many(
                        scale=(:Internode, :Leaf),
                        within=PlantSimEngine.Subtree(),
                    );
                    vars=(reserve=PlantSimEngine.Default(0.0),),
                ),
            ),
        ),
        ModelSpec(
            OrganReserveFilling();
            name=:xpalm_test_reserve_filling,
            on=Many(scale=:Plant),
            inputs=(
                :potential_reserve_organs => Many(
                    scale=(:Internode, :Leaf),
                    within=PlantSimEngine.Subtree(),
                    application=:xpalm_test_allocation_inputs,
                    var=:potential_reserve,
                ),
                :reserve_organs => Many(
                    scale=(:Internode, :Leaf),
                    within=PlantSimEngine.Subtree(),
                    application=:xpalm_test_carbon_allocation,
                    var=:reserve,
                ),
            ),
            outputs_to=(reserve=PlantSimEngine.OutputTo(
                Many(
                    scale=(:Internode, :Leaf),
                    within=PlantSimEngine.Subtree(),
                );
                vars=(reserve=PlantSimEngine.Default(0.0),),
            ),),
            updates=PlantSimEngine.Updates(
                :reserve;
                after=:xpalm_test_carbon_allocation,
            ),
        ),
    )
end

function xpalm_test_allocation_scene(; mismatched_allocations=false)
    objects = (
        Object(500; scale=:Scene),
        Object(
            901;
            scale=:Plant,
            parent=500,
            status=Status(carbon_offer_after_rm=2.0),
        ),
        Object(
            73;
            scale=:Leaf,
            parent=901,
            status=Status(
                carbon_demand_seed=4.0,
                potential_reserve_seed=2.0,
                reserve=3.0,
            ),
        ),
        Object(
            11;
            scale=:Internode,
            parent=901,
            status=Status(
                carbon_demand_seed=2.0,
                potential_reserve_seed=4.0,
                reserve=1.0,
            ),
        ),
        Object(
            207;
            scale=:Plant,
            parent=500,
            status=Status(carbon_offer_after_rm=10.0),
        ),
        Object(
            31;
            scale=:Leaf,
            parent=207,
            status=Status(
                carbon_demand_seed=1.0,
                potential_reserve_seed=2.0,
                reserve=5.0,
            ),
        ),
        Object(
            888;
            scale=:Internode,
            parent=207,
            status=Status(
                carbon_demand_seed=3.0,
                potential_reserve_seed=4.0,
                reserve=1.0,
            ),
        ),
        Object(
            333;
            scale=:Plant,
            parent=500,
            status=Status(carbon_offer_after_rm=7.0),
        ),
    )
    return CompositeModel(
        objects...;
        applications=xpalm_test_allocation_applications(
            ; mismatched_allocations=mismatched_allocations,
        ),
        environment=(duration=Day(1),),
    )
end

function xpalm_test_status(model, id)
    return PlantSimEngine.model_object(model, id).status
end

function xpalm_test_sum_allocations(values, initial)
    return @allocated XPalm.Models._sum_with_initial(values, initial)
end

function xpalm_test_allocation_kernel_allocations(
    model,
    carbon_demands,
    previous_reserves,
    carbon_allocations,
    current_reserves,
    carbon_offer,
)
    return @allocated XPalm.Models._allocate_organ_carbon!(
        model,
        carbon_demands,
        previous_reserves,
        carbon_allocations,
        current_reserves,
        carbon_offer,
    )
end

function xpalm_test_reserve_kernel_allocations(
    potential_reserves,
    reserves_before_filling,
    current_reserves,
    carbon_offer,
)
    return @allocated XPalm.Models._fill_organ_reserves!(
        potential_reserves,
        reserves_before_filling,
        current_reserves,
        carbon_offer,
    )
end

function xpalm_test_registry_status_ownership(model)
    for object in model_objects(model)
        node = PlantSimEngine.source_node(model, object)
        @test PlantSimEngine.model_object(model, node) === object
        @test PlantSimEngine.model_status(model, node) === object.status
        @test !haskey(
            MultiScaleTreeGraph.node_attributes(node),
            :plantsimengine_status,
        )
    end
    return nothing
end

function xpalm_test_polluted_status_attribute_rejection()
    palm = Palm(
        initiation_age=0,
        parameters=XPalm.default_parameters(),
    )
    palm.mtg[:plantsimengine_status] = Status(polluted=true)
    exception = try
        XPalm.xpalm_scene(
            palm;
            architecture=false,
            environment=meteo[1:1, :],
        )
        nothing
    catch err
        err
    end
    @test exception isa ErrorException
    if exception isa Exception
        message = sprint(showerror, exception)
        @test occursin("legacy `plantsimengine_status`", message)
        @test occursin("Remove it from the persisted graph", message)
        @test occursin("PlantSimEngine.model_status", message)
    end
    return nothing
end

@testset "carbon_allocation" begin
    @testset "runtime status ownership" begin
        xpalm_test_polluted_status_attribute_rejection()
    end

    @testset "allocation and reserve math" begin
        homogeneous_float32 = Float32[0.25, 0.5]
        homogeneous_float32_sum = @inferred XPalm.Models._sum_with_initial(
            homogeneous_float32,
            0.25f0,
        )
        @test homogeneous_float32_sum === 1.0f0

        float64_values = Float64[0.25, 0.5]
        integer_offer_sum = @inferred XPalm.Models._sum_with_initial(
            float64_values,
            1,
        )
        @test integer_offer_sum === 1.75

        precision_values = Float64[1.0e-12, 2.0e-12]
        float32_offer_sum = @inferred XPalm.Models._sum_with_initial(
            precision_values,
            1.0f0,
        )
        @test float32_offer_sum === 1.000000000003
        @test float32_offer_sum > Float64(1.0f0)

        XPalm.Models._sum_with_initial(homogeneous_float32, 0.25f0)
        XPalm.Models._sum_with_initial(float64_values, 1)
        XPalm.Models._sum_with_initial(precision_values, 1.0f0)
        @test xpalm_test_sum_allocations(
            homogeneous_float32,
            0.25f0,
        ) == 0
        @test xpalm_test_sum_allocations(float64_values, 1) == 0
        @test xpalm_test_sum_allocations(precision_values, 1.0f0) == 0

        model = OrgansCarbonAllocationModel(
            ; cost_reserve_mobilization=2.0,
        )
        carbon_demands = [4.0, 2.0]
        previous_reserves = [3.0, 1.0]
        carbon_allocations = zeros(2)
        current_reserves = zeros(2)

        result = XPalm.Models._allocate_organ_carbon!(
            model,
            carbon_demands,
            previous_reserves,
            carbon_allocations,
            current_reserves,
            2.0,
        )
        @test result.reserve == 0.0
        @test result.carbon_allocation == 4.0
        @test carbon_allocations ≈ [8 / 3, 4 / 3]
        @test current_reserves == [0.0, 0.0]
        @test result.respiration_reserve_mobilization == 2.0
        @test result.carbon_offer_after_allocation == 0.0

        mixed_carbon_allocations = zeros(2)
        mixed_current_reserves = zeros(2)
        mixed_result = @inferred XPalm.Models._allocate_organ_carbon!(
            model,
            carbon_demands,
            previous_reserves,
            mixed_carbon_allocations,
            mixed_current_reserves,
            2,
        )
        @test all(value -> value isa Float64, values(mixed_result))
        @test mixed_result == result
        @test xpalm_test_allocation_kernel_allocations(
            model,
            carbon_demands,
            previous_reserves,
            mixed_carbon_allocations,
            mixed_current_reserves,
            2,
        ) == 0

        float32_model = OrgansCarbonAllocationModel(
            ; cost_reserve_mobilization=2.0f0,
        )
        float32_demands = Float32[4.0, 2.0]
        float32_reserves = Float32[3.0, 1.0]
        float32_allocations = zeros(Float32, 2)
        float32_current_reserves = zeros(Float32, 2)
        float32_result = @inferred XPalm.Models._allocate_organ_carbon!(
            float32_model,
            float32_demands,
            float32_reserves,
            float32_allocations,
            float32_current_reserves,
            2.0f0,
        )
        @test all(value -> value isa Float32, values(float32_result))
        @test float32_result.carbon_allocation === 4.0f0
        @test float32_result.respiration_reserve_mobilization === 2.0f0
        @test xpalm_test_allocation_kernel_allocations(
            float32_model,
            float32_demands,
            float32_reserves,
            float32_allocations,
            float32_current_reserves,
            2.0f0,
        ) == 0

        result = XPalm.Models._allocate_organ_carbon!(
            model,
            carbon_demands,
            previous_reserves,
            carbon_allocations,
            current_reserves,
            10.0,
        )
        @test result.carbon_allocation == 6.0
        @test result.reserve == 4.0
        @test current_reserves == previous_reserves
        @test result.respiration_reserve_mobilization == 0.0
        @test result.carbon_offer_after_allocation == 4.0

        zero_demands = zeros(2)
        result = XPalm.Models._allocate_organ_carbon!(
            model,
            zero_demands,
            previous_reserves,
            carbon_allocations,
            current_reserves,
            5.0,
        )
        @test result.carbon_allocation == 0.0
        @test carbon_allocations == [0.0, 0.0]
        @test current_reserves == previous_reserves
        @test result.respiration_reserve_mobilization == 0.0
        @test result.carbon_offer_after_allocation == 5.0

        zero_reserves = zeros(2)
        result = XPalm.Models._allocate_organ_carbon!(
            model,
            carbon_demands,
            zero_reserves,
            carbon_allocations,
            current_reserves,
            2.0,
        )
        @test result.carbon_allocation == 2.0
        @test result.reserve == 0.0
        @test result.respiration_reserve_mobilization == 0.0
        @test current_reserves == zero_reserves

        empty_values = Float64[]
        result = XPalm.Models._allocate_organ_carbon!(
            model,
            empty_values,
            empty_values,
            empty_values,
            empty_values,
            3.0,
        )
        @test result.carbon_demand == 0.0
        @test result.reserve == 0.0
        @test result.carbon_offer_after_allocation == 3.0

        XPalm.Models._allocate_organ_carbon!(
            model,
            carbon_demands,
            previous_reserves,
            carbon_allocations,
            current_reserves,
            2.0,
        )
        @test @allocated(
            XPalm.Models._allocate_organ_carbon!(
                model,
                carbon_demands,
                previous_reserves,
                carbon_allocations,
                current_reserves,
                2.0,
            )
        ) == 0

        potential_reserves = [2.0, 4.0]
        reserves_before_filling = [1.0, 3.0]
        reserves_after_filling = zeros(2)
        filling = XPalm.Models._fill_organ_reserves!(
            potential_reserves,
            reserves_before_filling,
            reserves_after_filling,
            3.0,
        )
        @test filling.carbon_allocation_reserve == 3.0
        @test filling.reserve == 7.0
        @test filling.carbon_offer_after_storage == 0.0
        @test reserves_after_filling == [2.0, 5.0]

        mixed_reserves_after_filling = zeros(2)
        mixed_filling = @inferred XPalm.Models._fill_organ_reserves!(
            potential_reserves,
            reserves_before_filling,
            mixed_reserves_after_filling,
            3,
        )
        @test all(value -> value isa Float64, values(mixed_filling))
        @test mixed_filling == filling
        @test xpalm_test_reserve_kernel_allocations(
            potential_reserves,
            reserves_before_filling,
            mixed_reserves_after_filling,
            3,
        ) == 0

        float32_potential_reserves = Float32[2.0, 4.0]
        float32_reserves_before_filling = Float32[1.0, 3.0]
        float32_reserves_after_filling = zeros(Float32, 2)
        float32_filling = @inferred XPalm.Models._fill_organ_reserves!(
            float32_potential_reserves,
            float32_reserves_before_filling,
            float32_reserves_after_filling,
            3.0f0,
        )
        @test all(value -> value isa Float32, values(float32_filling))
        @test float32_filling.reserve === 7.0f0
        @test float32_filling.carbon_allocation_reserve === 3.0f0
        @test xpalm_test_reserve_kernel_allocations(
            float32_potential_reserves,
            float32_reserves_before_filling,
            float32_reserves_after_filling,
            3.0f0,
        ) == 0

        zero_potential = zeros(2)
        filling = XPalm.Models._fill_organ_reserves!(
            zero_potential,
            reserves_before_filling,
            reserves_after_filling,
            3.0,
        )
        @test filling.carbon_allocation_reserve == 0.0
        @test filling.reserve == 4.0
        @test reserves_after_filling == reserves_before_filling

        XPalm.Models._fill_organ_reserves!(
            potential_reserves,
            reserves_before_filling,
            reserves_after_filling,
            3.0,
        )
        @test @allocated(
            XPalm.Models._fill_organ_reserves!(
                potential_reserves,
                reserves_before_filling,
                reserves_after_filling,
                3.0,
            )
        ) == 0
    end

    @testset "identified multi-plant distributed outputs" begin
        identified_scene = xpalm_test_allocation_scene()
        identified_compiled =
            PlantSimEngine.Advanced.refresh_bindings!(identified_scene)
        identified_simulation = run!(
            identified_scene;
            steps=1,
            outputs=:all,
        )

        plant_1 = xpalm_test_status(identified_scene, 901)
        @test plant_1.carbon_allocation == 4.0
        @test plant_1.reserve == 0.0
        @test plant_1.respiration_reserve_mobilization == 2.0
        @test xpalm_test_status(identified_scene, 73).carbon_allocation ≈
              8 / 3
        @test xpalm_test_status(identified_scene, 11).carbon_allocation ≈
              4 / 3
        @test xpalm_test_status(identified_scene, 73).reserve == 0.0
        @test xpalm_test_status(identified_scene, 11).reserve == 0.0

        plant_2 = xpalm_test_status(identified_scene, 207)
        @test plant_2.carbon_allocation == 4.0
        @test plant_2.reserve == 12.0
        @test plant_2.respiration_reserve_mobilization == 0.0
        @test xpalm_test_status(identified_scene, 31).carbon_allocation == 1.0
        @test xpalm_test_status(identified_scene, 888).carbon_allocation == 3.0
        @test xpalm_test_status(identified_scene, 31).reserve == 7.0
        @test xpalm_test_status(identified_scene, 888).reserve == 5.0

        empty_plant = xpalm_test_status(identified_scene, 333)
        @test empty_plant.carbon_allocation == 0.0
        @test empty_plant.reserve == 0.0
        @test empty_plant.carbon_offer_after_storage == 7.0

        previous_reserve_bindings = [
            binding for binding in identified_compiled.input_bindings
            if binding.application_id == :xpalm_test_carbon_allocation &&
               binding.input == :previous_reserve_organs
        ]
        @test length(previous_reserve_bindings) == 3
        @test all(
            binding -> binding.policy isa PlantSimEngine.PreviousTimeStep,
            previous_reserve_bindings,
        )
        previous_reserve_source_ids = Dict(
            binding.consumer_id.value =>
                getproperty.(binding.source_ids, :value)
            for binding in previous_reserve_bindings
        )
        @test previous_reserve_source_ids == Dict(
            901 => [11, 73],
            207 => [31, 888],
            333 => Int[],
        )

        writer_rows = PlantSimEngine.Diagnostics.explain_writers(
            identified_compiled,
        )
        @test any(writer_rows) do row
            row.object_id == 31 &&
                row.variable == :carbon_allocation &&
                row.application_ids == [:xpalm_test_carbon_allocation]
        end
        @test any(writer_rows) do row
            row.object_id == 31 &&
                row.variable == :reserve &&
                row.application_ids == [
                    :xpalm_test_carbon_allocation,
                    :xpalm_test_reserve_filling,
                ] &&
                row.update_application_ids == [:xpalm_test_reserve_filling]
        end

        retained = PlantSimEngine.collect_outputs(
            identified_simulation,
            31,
            :carbon_allocation;
            sink=nothing,
        )
        @test only(retained).value == 1.0
    end

    @testset "ID mismatch fails before mutation" begin
        mismatched_scene = xpalm_test_allocation_scene(
            ; mismatched_allocations=true,
        )
        @test_throws ArgumentError run!(
            mismatched_scene;
            steps=1,
            outputs=:none,
        )
        @test xpalm_test_status(mismatched_scene, 73).carbon_allocation == 0.0
        @test xpalm_test_status(mismatched_scene, 31).carbon_allocation == 0.0
        @test xpalm_test_status(mismatched_scene, 73).reserve == 3.0
        @test xpalm_test_status(mismatched_scene, 11).reserve == 1.0
    end

    scene = XPalm.xpalm_scene(
        Palm(
            initiation_age=0,
            parameters=XPalm.default_parameters(),
        );
        architecture=false,
        environment=meteo[1:1, :],
    )
    xpalm_test_registry_status_ownership(scene)
    for organ in model_objects(scene)
        organ.scale in (:Internode, :Leaf) || continue
        @test :carbon_allocation ∉ propertynames(organ.status)
        @test :reserve ∉ propertynames(organ.status)
    end
    compiled = PlantSimEngine.Advanced.refresh_bindings!(scene)
    schedule_positions = Dict(
        row.application_id => row.execution_index
        for row in PlantSimEngine.Diagnostics.explain_schedule(compiled)
    )

    @test schedule_positions[:Plant__carbon_allocation] <
          schedule_positions[:Internode__biomass]
    @test schedule_positions[:Plant__carbon_allocation] <
          schedule_positions[:Leaf__biomass]
    @test schedule_positions[:Plant__carbon_allocation] <
          schedule_positions[:Plant__reserve_filling]
    @test schedule_positions[:Plant__reserve_filling] <
          schedule_positions[:Leaf__leaf_pruning]

    previous_reserve_binding = only(
        binding for binding in compiled.input_bindings
        if binding.application_id == :Plant__carbon_allocation &&
           binding.input == :previous_reserve_organs
    )
    @test previous_reserve_binding.policy isa
          PlantSimEngine.PreviousTimeStep
    @test previous_reserve_binding.source_application_ids == [
        :Plant__reserve_filling,
        :Leaf__leaf_pruning,
    ]
    @test previous_reserve_binding.source_ids ==
          PlantSimEngine.ObjectId.(Int[7, 8])
    @test PlantSimEngine.Diagnostics.has_reference_carrier(
        previous_reserve_binding,
    )
    previous_reserve_default = PlantSimEngine.inputs_(
        OrgansCarbonAllocationModel(),
    ).previous_reserve_organs
    @test previous_reserve_default isa PlantSimEngine.Default
    @test isempty(previous_reserve_default.value)

    for organ in model_objects(scene)
        organ.scale in (:Internode, :Leaf) || continue
        @test organ.status.carbon_allocation == 0.0
        @test organ.status.reserve == 0.0
    end

    run!(scene; steps=1, outputs=:none)
    for organ in model_objects(scene)
        organ.scale in (:Internode, :Leaf) || continue
        @test isfinite(organ.status.carbon_allocation)
        @test organ.status.reserve >= 0.0
    end

    lifecycle_scene = XPalm.xpalm_scene(
        Palm(
            initiation_age=0,
            parameters=XPalm.default_parameters(),
        );
        architecture=false,
        environment=meteo[1:12, :],
    )
    xpalm_test_registry_status_ownership(lifecycle_scene)
    initial_vegetative_organ_ids = Set(
        organ.id for organ in model_objects(lifecycle_scene)
        if organ.scale in (:Internode, :Leaf)
    )
    initial_phytomer_count = length(
        model_objects(lifecycle_scene; scale=:Phytomer),
    )
    run!(lifecycle_scene; steps=12, outputs=:none)
    xpalm_test_registry_status_ownership(lifecycle_scene)
    @test length(model_objects(lifecycle_scene; scale=:Phytomer)) >
          initial_phytomer_count
    lifecycle_plant = only(model_objects(lifecycle_scene; scale=:Plant))
    last_phytomer = lifecycle_plant.status.last_phytomer
    @test last_phytomer isa PlantSimEngine.ObjectId
    last_phytomer_object = PlantSimEngine.model_object(
        lifecycle_scene,
        last_phytomer,
    )
    @test last_phytomer_object.id == last_phytomer
    @test last_phytomer_object.scale == :Phytomer
    newborn_vegetative_organs = [
        organ for organ in model_objects(lifecycle_scene)
        if organ.scale in (:Internode, :Leaf) &&
           !(organ.id in initial_vegetative_organ_ids)
    ]
    @test !isempty(newborn_vegetative_organs)
    @test all(organ -> isfinite(organ.status.Rm), newborn_vegetative_organs)
    for organ in model_objects(lifecycle_scene)
        organ.scale in (:Internode, :Leaf, :Male, :Female) || continue
        @test isfinite(organ.status.Rm)
        @test isfinite(organ.status.carbon_allocation)
        if organ.scale in (:Internode, :Leaf)
            @test organ.status.reserve >= 0.0
        end
    end
end
