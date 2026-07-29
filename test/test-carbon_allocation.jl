@testset "carbon_allocation" begin
    model = OrgansCarbonAllocationModel(; cost_reserve_mobilization=2.0)
    previous_reserve_organs = [3.0, 1.0]
    current_reserve_organs = [-1.0, -1.0]
    status = Status(
        carbon_offer_after_rm=2.0,
        carbon_demand_organs=[4.0, 2.0],
        carbon_allocation_organs=zeros(2),
        previous_reserve_organs=previous_reserve_organs,
        carbon_allocation=-Inf,
        respiration_reserve_mobilization=-Inf,
        carbon_offer_after_allocation=-Inf,
        carbon_demand=0.0,
        reserve=-1.0,
        reserve_organs=current_reserve_organs,
    )

    run!(model, nothing, status, nothing, nothing)

    @test status.previous_reserve_organs == [3.0, 1.0]
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
        for row in PlantSimEngine.explain_schedule(compiled)
    )

    @test schedule_positions[:Plant__carbon_allocation] <
          schedule_positions[:Internode__carbon_allocation_state_publisher] <
          schedule_positions[:Internode__biomass]
    @test schedule_positions[:Plant__carbon_allocation] <
          schedule_positions[:Leaf__carbon_allocation_state_publisher] <
          schedule_positions[:Leaf__biomass]
    @test schedule_positions[:Plant__reserve_filling] <
          schedule_positions[:Internode__reserve_state_publisher]
    @test schedule_positions[:Plant__reserve_filling] <
          schedule_positions[:Leaf__reserve_state_publisher]

    previous_reserve_binding = only(
        binding for binding in compiled.input_bindings
        if binding.application_id == :Plant__carbon_allocation &&
           binding.input == :previous_reserve_organs
    )
    @test previous_reserve_binding.policy isa PreviousTimeStep
    @test previous_reserve_binding.source_application_ids ==
          [:Plant__reserve_filling]

    run!(scene; steps=1, outputs=:none)
    for organ in model_objects(scene)
        organ.scale in (:Internode, :Leaf) || continue
        @test isfinite(organ.status.carbon_allocation)
        @test organ.status.reserve >= 0.0
    end
end
