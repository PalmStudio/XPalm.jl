"""
OrgansCarbonAllocationModel()

Compute the carbon to allocate to organs from photosysthesis and reserve mobilization (after maintenance respiration) 


# Arguments
- `cost_reserve_mobilization`: carbon cost to mobilize carbon reserve from stem or leaves

"""
struct OrgansCarbonAllocationModel{T} <: AbstractCarbon_AllocationModel
    cost_reserve_mobilization::T # 1.667
end

OrgansCarbonAllocationModel(; cost_reserve_mobilization=1.667) = OrgansCarbonAllocationModel(cost_reserve_mobilization)

PlantSimEngine.inputs_(::OrgansCarbonAllocationModel) = (
    carbon_offer_after_rm=PlantSimEngine.Required(Real),
    carbon_demand_organs=PlantSimEngine.Required(AbstractVector),
    previous_reserve_organs=PlantSimEngine.Default(Float64[]),
)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel) = (
    carbon_allocation=-Inf,
    respiration_reserve_mobilization=-Inf,
    carbon_offer_after_allocation=-Inf,
    carbon_demand=0.0,
    reserve=0.0,
)

@inline function _allocate_organ_carbon!(
    m::OrgansCarbonAllocationModel,
    carbon_demands,
    previous_reserves,
    carbon_allocations,
    current_reserves,
    carbon_offer_after_rm,
)
    initial_respiration = oftype(float(carbon_offer_after_rm), -Inf)
    return _allocate_organ_carbon!(
        m,
        carbon_demands,
        previous_reserves,
        carbon_allocations,
        current_reserves,
        carbon_offer_after_rm,
        initial_respiration,
    )
end

@inline function _allocate_organ_carbon!(
    m::OrgansCarbonAllocationModel,
    carbon_demands,
    previous_reserves,
    carbon_allocations,
    current_reserves,
    carbon_offer_after_rm,
    respiration_reserve_mobilization,
)
    carbon_demand =
        _sum_with_initial(carbon_demands, zero(carbon_offer_after_rm))
    reserve_before_mobilization =
        _sum_with_initial(previous_reserves, zero(carbon_offer_after_rm))
    calculation_type = promote_type(
        typeof(carbon_demand),
        typeof(reserve_before_mobilization),
        typeof(carbon_offer_after_rm),
        typeof(m.cost_reserve_mobilization),
    )
    carbon_demand = convert(calculation_type, carbon_demand)
    reserve_before_mobilization =
        convert(calculation_type, reserve_before_mobilization)
    carbon_offer = convert(calculation_type, carbon_offer_after_rm)
    mobilization_cost =
        convert(calculation_type, m.cost_reserve_mobilization)
    respiration_reserve_mobilization =
        convert(calculation_type, respiration_reserve_mobilization)

    if carbon_demand > zero(carbon_demand)
        if carbon_demand <= carbon_offer
            carbon_allocation = carbon_demand
            carbon_offer_after_allocation =
                carbon_offer - carbon_allocation
            reserve_mobilized = zero(reserve_before_mobilization)
        else
            reserve_available =
                reserve_before_mobilization / mobilization_cost
            carbon_offer_after_allocation = zero(carbon_offer)
            if carbon_demand <= carbon_offer + reserve_available
                carbon_allocation = carbon_demand
                reserve_needed = carbon_demand - carbon_offer
                reserve_mobilized = reserve_needed * mobilization_cost
                respiration_reserve_mobilization =
                    reserve_mobilized - reserve_needed
            else
                carbon_allocation = carbon_offer + reserve_available
                reserve_mobilized = reserve_before_mobilization
                respiration_reserve_mobilization =
                    reserve_mobilized - reserve_available
            end
        end

        @inbounds for index in eachindex(carbon_demands, carbon_allocations)
            carbon_allocations[index] =
                carbon_allocation * carbon_demands[index] / carbon_demand
        end
    else
        carbon_allocation = zero(carbon_demand)
        carbon_offer_after_allocation = carbon_offer
        reserve_mobilized = zero(reserve_before_mobilization)
        @inbounds for index in eachindex(carbon_allocations)
            carbon_allocations[index] = zero(eltype(carbon_allocations))
        end
    end

    if reserve_before_mobilization != zero(reserve_before_mobilization)
        @inbounds for index in eachindex(previous_reserves, current_reserves)
            previous_reserve = previous_reserves[index]
            current_reserves[index] = previous_reserve -
                reserve_mobilized * previous_reserve /
                reserve_before_mobilization
        end
    else
        @inbounds for index in eachindex(previous_reserves, current_reserves)
            current_reserves[index] = previous_reserves[index]
        end
    end

    return (
        carbon_demand=carbon_demand,
        reserve=reserve_before_mobilization - reserve_mobilized,
        carbon_allocation=carbon_allocation,
        respiration_reserve_mobilization=respiration_reserve_mobilization,
        carbon_offer_after_allocation=carbon_offer_after_allocation,
    )
end

function PlantSimEngine.run!(
    m::OrgansCarbonAllocationModel,
    status,
    environment,
    constants,
    context,
)
    carbon_demands =
        PlantSimEngine.bound_input(context, :carbon_demand_organs)
    previous_reserves =
        PlantSimEngine.bound_input(context, :previous_reserve_organs)
    allocation_targets =
        PlantSimEngine.output_targets(context, :carbon_allocation)
    reserve_targets = PlantSimEngine.output_targets(context, :reserve)

    _require_aligned_object_ids(
        :carbon_demand_organs,
        :carbon_allocation,
        PlantSimEngine.object_ids(carbon_demands),
        PlantSimEngine.object_ids(allocation_targets),
    )
    _require_aligned_object_ids(
        :previous_reserve_organs,
        :reserve,
        PlantSimEngine.object_ids(previous_reserves),
        PlantSimEngine.object_ids(reserve_targets),
    )

    result = _allocate_organ_carbon!(
        m,
        carbon_demands,
        previous_reserves,
        allocation_targets.columns.carbon_allocation,
        reserve_targets.columns.reserve,
        status.carbon_offer_after_rm,
        status.respiration_reserve_mobilization,
    )
    status.carbon_demand = result.carbon_demand
    status.reserve = result.reserve
    status.carbon_allocation = result.carbon_allocation
    status.respiration_reserve_mobilization =
        result.respiration_reserve_mobilization
    status.carbon_offer_after_allocation =
        result.carbon_offer_after_allocation
    return nothing
end
