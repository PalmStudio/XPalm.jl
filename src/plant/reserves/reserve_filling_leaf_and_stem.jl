struct OrganReserveFilling{T,O} <: AbstractReserve_FillingModel
    lma_min::T
    lma_max::T
    leaflets_biomass_contribution::T
    nsc_max::T
end

function OrganReserveFilling(
    lma_min::T,
    lma_max::T,
    leaflets_biomass_contribution::T,
    nsc_max::T,
) where {T}
    OrganReserveFilling{T,Any}(lma_min, lma_max, leaflets_biomass_contribution, nsc_max)
end

function OrganReserveFilling{O}(
    lma_min::T=80.0,
    lma_max::T=200.0,
    leaflets_biomass_contribution::T=0.35,
    nsc_max::T=0.3,
) where {T,O}
    OrganReserveFilling{T,O}(lma_min, lma_max, leaflets_biomass_contribution, nsc_max)
end

PlantSimEngine.inputs_(::OrganReserveFilling) = (carbon_offer_after_allocation=-Inf,)
PlantSimEngine.outputs_(::OrganReserveFilling) = (reserve=0.0, carbon_allocation_reserve=-Inf, carbon_offer_after_storage=-Inf,)

# The model makes computations for the organs from the Plant scale, so we only need the output for them:
PlantSimEngine.inputs_(::OrganReserveFilling{T}) where {T<:Union{Leaf,Stem}} = NamedTuple()
PlantSimEngine.outputs_(::OrganReserveFilling{T}) where {T<:Union{Leaf,Stem}} = (reserve=0.0,)

# Applied at the plant scale:
function PlantSimEngine.run!(m::OrganReserveFilling, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    timestep = rownumber(st)

    @assert mtg.MTG.symbol == "Plant" "The node should be a Plant but is a $(mtg.MTG.symbol)"

    organ_reserve_potential = Vector{typeof(st.carbon_offer_after_allocation)}()

    MultiScaleTreeGraph.traverse!(mtg, symbol=["Leaf", "Internode"]) do organ
        st_organ = organ[:models].status[timestep]

        if organ.MTG.symbol == "Leaf"
            if st_organ.leaf_state == "Opened"
                organ_reserve_max = (m.lma_max - m.lma_min) * st_organ.leaf_area / m.leaflets_biomass_contribution
                push!(organ_reserve_potential, organ_reserve_max - st_organ.reserve)
            else
                push!(organ_reserve_potential, 0.0)
            end
        else
            # This is the potential reserve for the internode:
            push!(organ_reserve_potential, st_organ.biomass * m.nsc_max - st_organ.reserve)
        end
    end

    total_reserve_potential_organ = sum(organ_reserve_potential)

    if total_reserve_potential_organ > 0.0
        # Proportion of the demand of each organ compared to the total organ demand: 
        proportion_carbon_potential = organ_reserve_potential ./ total_reserve_potential_organ
        st.carbon_allocation_reserve = min(total_reserve_potential_organ, st.carbon_offer_after_allocation)
        carbon_reserve_organ = st.carbon_allocation_reserve .* proportion_carbon_potential
    else
        # If the potential carbon storage is 0.0, we allocate nothing:
        st.carbon_allocation_reserve = 0.0
        carbon_reserve_organ = zeros(typeof(organ_reserve_potential[1]), length(organ_reserve_potential))
    end

    total_reserves = Vector{typeof(st.carbon_offer_after_allocation)}()
    sizehint!(total_reserves, length(carbon_reserve_organ))
    MultiScaleTreeGraph.traverse!(mtg, symbol=["Leaf", "Internode"]) do organ
        organ[:models].status[timestep].reserve += popfirst!(carbon_reserve_organ)
        push!(total_reserves, organ[:models].status[timestep].reserve)
        # Note: the reserve from the day before was already propagated to the current day just above so we 
        # can just add the new allocated reserve
    end

    st.reserve = sum(total_reserves)
    st.carbon_offer_after_storage = st.carbon_offer_after_allocation - st.carbon_allocation_reserve
end