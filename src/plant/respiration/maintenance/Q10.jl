"""
    RmQ10FixedN(Q10, Rm_base, T_ref, P_alive, nitrogen_content)

Maintenance respiration based on a Q10 computation with fixed nitrogen values 
and proportion of living cells in the organs.

# Arguments

- `Q10`: Q10 factor (values should usually range between: 1.5 - 2.5, with 2.1 being the most common value)
- `Rm_base`: Base maintenance respiration (gC gDM⁻¹ d⁻¹). Should be around 0.06.
- `T_ref`: Reference temperature at which Q10 was measured (usually around 25.0°C)
- `P_alive`: proportion of living cells in the organ
- `nitrogen_content`: nitrogen content of the organ (gN gC⁻¹)
"""
struct RmQ10FixedN{T} <: AbstractMaintenance_RespirationModel
    Q10::T
    Rm_base::T
    T_ref::T
    P_alive::T
    nitrogen_content::T
end

# RmQ10FixedN{O}(Q10, Rm_base, T_ref=25.0) where {O<:Organ} = RmQ10FixedN{O,typeof(Q10)}(Q10, Rm_base, T_ref)

PlantSimEngine.inputs_(::RmQ10FixedN) = (biomass=-Inf,)
PlantSimEngine.outputs_(::RmQ10FixedN) = (Rm=-Inf,)

function PlantSimEngine.run!(::RmQ10FixedN, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    timestep = rownumber(status)
    status.Rm = 0.0
    MultiScaleTreeGraph.traverse(mtg, symbol=["Leaf", "Internode"]) do organ
        PlantSimEngine.run!(organ[:models].models.maintenance_respiration, organ[:models].models, organ[:models].status[timestep], meteo, constants, nothing)
        status.Rm += organ[:models].status[timestep].Rm
    end
end

# Standard way of computing the Rm of an organ:
function PlantSimEngine.run!(m::RmQ10FixedN, models, status, meteo, constants, extra=nothing)
    biomass = prev_value(status, :biomass, default=status.biomass)
    if biomass == -Inf
        biomass = status.biomass
    end
    status.Rm =
        biomass * m.P_alive * m.nitrogen_content * m.Rm_base *
        m.Q10^(((meteo.Tmax + meteo.Tmin) / 2.0 - m.T_ref) / 10.0)
end
