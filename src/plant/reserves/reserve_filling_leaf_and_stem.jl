struct OrganReserveFilling <: AbstractReserve_FillingModel end

PlantSimEngine.inputs_(::OrganReserveFilling) = (
    carbon_offer_after_allocation=PlantSimEngine.Required(Real),
    potential_reserve_organs=PlantSimEngine.Required(AbstractVector),
    reserve_organs=PlantSimEngine.Required(AbstractVector),
)
PlantSimEngine.outputs_(::OrganReserveFilling) = (
    reserve=0.0,
    carbon_allocation_reserve=-Inf,
    carbon_offer_after_storage=-Inf,
)

@inline function _fill_organ_reserves!(
    potential_reserves,
    reserves_before_filling,
    current_reserves,
    carbon_offer_after_allocation,
)
    total_reserve_potential_organ = _sum_with_initial(
        potential_reserves,
        zero(carbon_offer_after_allocation),
    )
    calculation_type = promote_type(
        typeof(total_reserve_potential_organ),
        typeof(carbon_offer_after_allocation),
    )
    total_reserve_potential_organ =
        convert(calculation_type, total_reserve_potential_organ)
    carbon_offer =
        convert(calculation_type, carbon_offer_after_allocation)

    if total_reserve_potential_organ > zero(total_reserve_potential_organ)
        carbon_allocation_reserve = min(
            total_reserve_potential_organ,
            carbon_offer,
        )
        @inbounds for index in eachindex(
            potential_reserves,
            reserves_before_filling,
            current_reserves,
        )
            current_reserves[index] = reserves_before_filling[index] +
                carbon_allocation_reserve * potential_reserves[index] /
                total_reserve_potential_organ
        end
    else
        carbon_allocation_reserve = zero(carbon_offer)
        @inbounds for index in eachindex(
            reserves_before_filling,
            current_reserves,
        )
            current_reserves[index] = reserves_before_filling[index]
        end
    end

    return (
        reserve=_sum_with_initial(
            current_reserves,
            zero(carbon_offer),
        ),
        carbon_allocation_reserve=carbon_allocation_reserve,
        carbon_offer_after_storage=
            carbon_offer - carbon_allocation_reserve,
    )
end

# Applied at the plant scale:
function PlantSimEngine.run!(
    ::OrganReserveFilling,
    status,
    environment,
    constants,
    context,
)
    potential_reserves =
        PlantSimEngine.bound_input(context, :potential_reserve_organs)
    reserves_before_filling =
        PlantSimEngine.bound_input(context, :reserve_organs)
    reserve_targets = PlantSimEngine.output_targets(context, :reserve)

    reserve_target_ids = PlantSimEngine.object_ids(reserve_targets)
    _require_aligned_object_ids(
        :potential_reserve_organs,
        :reserve,
        PlantSimEngine.object_ids(potential_reserves),
        reserve_target_ids,
    )
    _require_aligned_object_ids(
        :reserve_organs,
        :reserve,
        PlantSimEngine.object_ids(reserves_before_filling),
        reserve_target_ids,
    )

    result = _fill_organ_reserves!(
        potential_reserves,
        reserves_before_filling,
        reserve_targets.columns.reserve,
        status.carbon_offer_after_allocation,
    )
    status.reserve = result.reserve
    status.carbon_allocation_reserve = result.carbon_allocation_reserve
    status.carbon_offer_after_storage = result.carbon_offer_after_storage

    return nothing
end
