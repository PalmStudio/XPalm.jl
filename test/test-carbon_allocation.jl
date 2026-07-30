@testset "carbon_allocation" begin
    model = OrgansCarbonAllocationModel(; cost_reserve_mobilization=2.0)
    reserve_organs = [3.0, 1.0]
    status = Status(
        carbon_offer_after_rm=2.0,
        carbon_demand_organs=[4.0, 2.0],
        carbon_allocation_organs=zeros(2),
        reserve_organs=reserve_organs,
        carbon_allocation=-Inf,
        respiration_reserve_mobilization=-Inf,
        carbon_offer_after_allocation=-Inf,
        carbon_demand=0.0,
        reserve=-1.0,
    )

    run!(model, status, nothing, nothing, nothing)

    @test status.reserve_organs == [0.0, 0.0]
    @test status.reserve == 0.0
    @test status.carbon_allocation == 4.0
    @test status.carbon_allocation_organs ≈ [8 / 3, 4 / 3]
    @test status.respiration_reserve_mobilization == 2.0
    @test status.carbon_offer_after_allocation == 0.0

    scene = XPalm.xpalm_scene(
        Palm(
            initiation_age=0,
            parameters=XPalm.default_parameters(),
        );
        architecture=false,
        environment=meteo[1:1, :],
    )
    compiled = PlantSimEngine.Advanced.refresh_bindings!(scene)
    schedule_positions = Dict(
        row.application_id => row.execution_index
        for row in PlantSimEngine.Diagnostics.explain_schedule(compiled)
    )

    @test schedule_positions[:Plant__carbon_allocation] <
          schedule_positions[:Internode__biomass]
    @test schedule_positions[:Plant__carbon_allocation] <
          schedule_positions[:Leaf__biomass]
    @test schedule_positions[:Plant__reserve_filling] <
          schedule_positions[:Leaf__leaf_pruning]

    reserve_binding = only(
        binding for binding in compiled.input_bindings
        if binding.application_id == :Plant__carbon_allocation &&
           binding.input == :reserve_organs
    )
    @test reserve_binding.policy isa PlantSimEngine.HoldLast
    @test isempty(reserve_binding.source_application_ids)
    @test PlantSimEngine.Diagnostics.has_reference_carrier(reserve_binding)

    run!(scene; steps=1, outputs=:none)
    for organ in model_objects(scene)
        organ.scale in (:Internode, :Leaf) || continue
        @test isfinite(organ.status.carbon_allocation)
        @test organ.status.reserve >= 0.0
    end
end
