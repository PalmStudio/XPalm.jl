struct RmQ10_BP{O,T} <: AbstractMaintenance_RespirationModel where {O,T}
    Q10::T
    Rm_base::T
    T_base::T
end

RmQ10{O}(Q10::T, Rm_base::T, T_base::T=25.0) where {O,T} = RmQ10{O,T}(Q10, Rm_base, T_base)

PlantSimEngine.inputs_(::RmQ10_BP) = (biomass=-Inf,)
PlantSimEngine.outputs_(::RmQ10_BP) = (Rm=-Inf,)

function PlantSimEngine.run!(m::RmQ10_BP, models, status, meteo, constants, extra=nothing)
    status.biomass * m.Rm_base * m.Q10^(((meteo.Tmax + meteo.Tmin) / 2.0 - m.T_base) / 10.0)
end

function PlantSimEngine.run!(::RmQ10_BP{Male,T} where {T}, models, status, meteo, constants, node, extra=nothing)

end
