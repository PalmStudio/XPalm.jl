struct LeafReserveFilling{T} <: AbstractReserve_FillingModel
    lma_min::T
    lma_max::T
    leaflets_biomass_contribution::T
end

PlantSimEngine.inputs_(::LeafReserveFilling) = (carbon_offer=-Inf, leaf_reserve_potential=-Inf,)
PlantSimEngine.outputs_(::LeafReserveFilling) = (reserve=0.0, carbon_allocation_reserve_leaves=-Inf, total_reserve_potential_leaves=-Inf)

# Applied at the plant scale:
function PlantSimEngine.run!(m::LeafReserveFilling, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    timestep = rownumber(st)

    @assert mtg.MTG.symbol == "Plant" "The node should be a Plant but is a $(mtg.MTG.symbol)"

    leaf_reserve_potential = Vector{typeof(st.leaf_reserve_potential)}()
    MultiScaleTreeGraph.traverse!(mtg, symbol="Leaf") do leaf
        st_leaf = leaf[:models].status[timestep]
        if st_leaf.leaf_state == "Opened"
            leaf_reserve_max = (m.lma_max - m.lma_min) * st_leaf.leaf_area / m.leaflets_biomass_contribution
            push!(leaf_reserve_potential, leaf_reserve_max - st_leaf.reserve)
        else
            push!(leaf_reserve_potential, 0.0)
        end
    end

    st.total_reserve_potential_leaves = sum(leaf_reserve_potential)

    if st.total_reserve_potential_leaves > 0.0
        # Proportion of the demand of each leaf compared to the total leaf demand: 
        proportion_carbon_potential = leaf_reserve_potential ./ st.total_reserve_potential_leaves
        st.carbon_allocation_reserve_leaves = min(st.total_reserve_potential_leaves, st.carbon_offer)
        carbon_reserve_leaf = st.carbon_allocation_reserve_leaves .* proportion_carbon_potential
    else
        # If the potential carbon storage is 0.0, we allocate nothing:
        st.carbon_allocation_reserve_leaves = 0.0
        carbon_reserve_leaf = zeros(typeof(leaf_reserve_potential[1]), length(leaf_reserve_potential))
    end

    MultiScaleTreeGraph.traverse!(mtg, symbol="Leaf") do leaf
        leaf[:models].status[timestep][:reserve] = leaf[:models].status[timestep].reserve + popfirst!(carbon_reserve_leaf)
    end

    st.carbon_offer -= st.carbon_allocation_reserve_leaves
end