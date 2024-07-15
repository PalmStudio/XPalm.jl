struct OrganReserveFilling <: AbstractReserve_FillingModel end

PlantSimEngine.inputs_(::OrganReserveFilling) = (carbon_offer_after_allocation=-Inf, potential_reserve_organs=[-Inf],)
PlantSimEngine.outputs_(::OrganReserveFilling) = (reserve=0.0, carbon_allocation_reserve=-Inf, carbon_offer_after_storage=-Inf, reserve_organs=[-Inf],)

# Applied at the plant scale:
function PlantSimEngine.run!(m::OrganReserveFilling, models, st, meteo, constants, extra=nothing)
    total_reserve_potential_organ = sum(st.potential_reserve_organs)

    if total_reserve_potential_organ > 0.0
        # Proportion of the demand of each organ compared to the total organ demand: 
        proportion_carbon_potential = st.potential_reserve_organs ./ total_reserve_potential_organ
        st.carbon_allocation_reserve = min(total_reserve_potential_organ, st.carbon_offer_after_allocation)
        st.reserve_organs .+= st.carbon_allocation_reserve .* proportion_carbon_potential
    else
        # If the potential carbon storage is 0.0, we allocate nothing:
        st.carbon_allocation_reserve = 0.0
    end

    # Plant total reserve:
    st.reserve = sum(st.reserve_organs)
    st.carbon_offer_after_storage = st.carbon_offer_after_allocation - st.carbon_allocation_reserve

    return nothing
end