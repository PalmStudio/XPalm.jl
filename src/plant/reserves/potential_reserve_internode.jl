struct PotentialReserveInternode{T} <: AbstractReserve_FillingModel
    nsc_max::T
end

PotentialReserveInternode(; nsc_max=0.3) = PotentialReserveInternode(nsc_max)

PlantSimEngine.inputs_(::PotentialReserveInternode) = (biomass=-Inf, reserve=0.0)
PlantSimEngine.outputs_(::PotentialReserveInternode) = (potential_reserve=0.0,)

function PlantSimEngine.run!(m::PotentialReserveInternode, models, st, meteo, constants, extra)
    st.potential_reserve = st.biomass * m.nsc_max - st.reserve
end