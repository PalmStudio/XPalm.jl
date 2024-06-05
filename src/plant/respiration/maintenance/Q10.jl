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

PlantSimEngine.inputs_(::RmQ10FixedN) = (biomass=0.0,)
PlantSimEngine.outputs_(::RmQ10FixedN) = (Rm=-Inf,)

# Standard way of computing the Rm of an organ:
function PlantSimEngine.run!(m::RmQ10FixedN, models, status, meteo, constants, extra=nothing)
    status.Rm =
        status.biomass * m.P_alive * m.nitrogen_content * m.Rm_base *
        m.Q10^(((meteo.Tmax + meteo.Tmin) / 2.0 - m.T_ref) / 10.0)
end


"""
    PlantRm()

Total plant maintenance respiration based on the sum of `Rm`.

# Intputs

- `Rm_organs`: a vector of maintenance respiration from all organs in the plant in gC d⁻¹

# Outputs

- `Rm`: the total plant maintenance respiration in gC d⁻¹
"""
struct PlantRm <: AbstractMaintenance_RespirationModel end

PlantSimEngine.inputs_(::PlantRm) = (Rm_organs=[-Inf],)
PlantSimEngine.outputs_(::PlantRm) = (Rm=-Inf,)

function PlantSimEngine.run!(::PlantRm, models, status, meteo, constants, extra=nothing)
    status.Rm = sum(status.Rm_organs)
end