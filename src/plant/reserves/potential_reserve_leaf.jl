struct PotentialReserveLeaf{T} <: AbstractReserve_FillingModel
    lma_min::T
    lma_max::T
    leaflets_biomass_contribution::T
end

PotentialReserveLeaf(; lma_min=80.0, lma_max=200.0, leaflets_biomass_contribution=0.35) = PotentialReserveLeaf(lma_min, lma_max, leaflets_biomass_contribution)

PlantSimEngine.inputs_(::PotentialReserveLeaf) = NamedTuple()
PlantSimEngine.outputs_(::PotentialReserveLeaf) = (potential_reserve=0.0,)

function PlantSimEngine.run!(m::PotentialReserveLeaf, models, st, meteo, constants, extra)
    if st.leaf_state == "Opened"
        st.potential_reserve = (m.lma_max - m.lma_min) * st.leaf_area / m.leaflets_biomass_contribution - st.reserve
    else
        st.potential_reserve = 0.0
    end

    return nothing
end


