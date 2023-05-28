struct LeafReserve <: AbstractReserveModel end

PlantSimEngine.inputs_(::LeafReserve) = NamedTuple()
PlantSimEngine.outputs_(::LeafReserve) = (reserve=-Inf,)

# Applied at the leaf scale:
function PlantSimEngine.run!(m::LeafReserve, models, st, meteo, constants, extra=nothing)
    st.reserve = 0.0
end