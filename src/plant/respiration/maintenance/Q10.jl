"""
    RmQ10FixedN(Q10, Mr, T_ref, P_alive)
    RmQ10FixedN(Q10, Turn, Prot, N, Gi, Mx, T_ref, P_alive)

Maintenance respiration based on a Q10 computation with fixed nitrogen values 
and proportion of living cells in the organs.

See those three references for more details:

Dufrene, Ochs, et Saugier, « Photosynthèse et productivité du palmier à huile en liaison avec les facteurs climatiques ».
Wit, Simulation of Assimilation, Respiration and Transpiration of Crops; DE VRIES, « The Cost of Maintenance Processes in Plant Cells ».
DE VRIES, « The Cost of Maintenance Processes in Plant Cells ».

# Arguments

- `Q10`: Q10 factor (values should usually range between: 1.5 - 2.5, with 2.1 being the most common value)
- `Mr`: maintenance respiration coefficient (gC gDM⁻¹). Should be around 0.06.
- `T_ref`: Reference temperature at which Q10 was measured (usually around 25.0°C)
- `P_alive`: proportion of living cells in the organ
- `Turn`: maintenance cost coefficient of the turnover of free proteins and membranes
- `Prot= 6.25`: nitrogen to protein conversion coefficient
- `N`: nitrogen content of the organ (gN gDM⁻¹)
- `Gi`: maintenance cost coefficient of the ionic gradient
- `Mx`:mineral content of the organ (g gDM⁻¹)
"""
struct RmQ10FixedN{T} <: AbstractMaintenance_RespirationModel
    Q10::T
    Mr::T
    T_ref::T
    P_alive::T
end

function RmQ10FixedN(Q10, Turn, Prot, N, Gi, Mx, T_ref, P_alive)
    Mr = Turn * Prot * N + Gi * Mx
    RmQ10FixedN(Q10, Mr, T_ref, P_alive)
end

PlantSimEngine.inputs_(::RmQ10FixedN) = (biomass=0.0,)
PlantSimEngine.outputs_(::RmQ10FixedN) = (Rm=-Inf,)

# Standard way of computing the Rm of an organ:
function PlantSimEngine.run!(m::RmQ10FixedN, models, status, meteo, constants, extra=nothing)
    status.Rm =
        status.biomass * m.P_alive * m.Mr * m.Q10^(((meteo.Tmax + meteo.Tmin) / 2.0 - m.T_ref) / 10.0)
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