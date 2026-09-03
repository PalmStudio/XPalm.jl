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
- `Mr`: maintenance respiration coefficient
  (g CH2O-equivalent gDM⁻¹ d⁻¹)
- `T_ref`: Reference temperature at which Q10 was measured (usually around 25.0°C)
- `P_alive`: proportion of living cells in the organ
- `Turn`: maintenance cost coefficient of the turnover of free proteins and membranes
- `Prot= 6.25`: nitrogen to protein conversion coefficient
- `N`: nitrogen content of the organ (gN gDM⁻¹)
- `Gi`: maintenance cost coefficient of the ionic gradient
- `Mx`:mineral content of the organ (g gDM⁻¹)

# Environment inputs

- `Tmin`, `Tmax`: daily minimum and maximum air temperatures (°C).

# Inputs

- `biomass`: organ structural dry mass (gDM); reserve carbon is a separate pool

# Outputs

- `Rm`: maintenance respiration (g CH2O-equivalent d⁻¹)
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

PlantSimEngine.inputs_(::RmQ10FixedN) = (
    biomass=PlantSimEngine.Required(Real),
)
PlantSimEngine.environment_inputs_(::RmQ10FixedN) = (
    Tmin=0.0,
    Tmax=0.0,
)
PlantSimEngine.outputs_(::RmQ10FixedN) = (Rm=-Inf,)
PlantSimEngine.variable_contracts_(::RmQ10FixedN) = (
    biomass=_STRUCTURAL_DRY_MASS,
    Rm=_DAILY_CH2O_EQUIVALENT_FLOW,
)

# Standard way of computing the Rm of an organ:
function PlantSimEngine.run!(m::RmQ10FixedN, status, environment, constants, context=nothing)
    status.Rm =
        status.biomass * m.P_alive * m.Mr * m.Q10^(((environment.Tmax + environment.Tmin) / 2.0 - m.T_ref) / 10.0)
end

"""
    PlantRm()

Total plant maintenance respiration based on the sum of `Rm`.

# Inputs

- `Rm_organs`: maintenance respiration of the plant organs
  (g CH2O-equivalent d⁻¹ per organ)

# Outputs

- `Rm`: total plant maintenance respiration (g CH2O-equivalent d⁻¹)
"""
struct PlantRm <: AbstractMaintenance_RespirationModel end

PlantSimEngine.inputs_(::PlantRm) = (
    Rm_organs=PlantSimEngine.Required(AbstractVector),
)
PlantSimEngine.outputs_(::PlantRm) = (Rm=-Inf,)
PlantSimEngine.variable_contracts_(::PlantRm) = (
    Rm_organs=_DAILY_CH2O_EQUIVALENT_FLOW,
    Rm=_DAILY_CH2O_EQUIVALENT_FLOW,
)

function PlantSimEngine.run!(::PlantRm, status, environment, constants, context=nothing)
    status.Rm = sum(status.Rm_organs)
end
