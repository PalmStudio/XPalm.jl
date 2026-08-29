"""
    ConstantRUEModel(rue)

Computes the `carbon_assimilation` using a constant radiation use efficiency (`rue`).

# Arguments

- `rue`: gross radiation use efficiency (g CH2O-equivalent MJ⁻¹)

# Inputs
- `aPPFD`: absorbed PAR in mol[photon] plant⁻¹ d⁻¹.

# Outputs
- `carbon_assimilation`: gross assimilate production
  (g CH2O-equivalent plant⁻¹ d⁻¹)
"""
struct ConstantRUEModel{T} <: AbstractCarbon_AssimilationModel
    rue::T
end

PlantSimEngine.inputs_(::ConstantRUEModel) = (
    aPPFD=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::ConstantRUEModel) = (carbon_assimilation=-Inf,)
PlantSimEngine.variable_contracts_(::ConstantRUEModel) = (
    aPPFD=_PLANT_DAILY_PAR_PHOTONS,
    carbon_assimilation=_DAILY_CH2O_EQUIVALENT_FLOW,
)

function PlantSimEngine.run!(m::ConstantRUEModel, status, environment, constants, context=nothing)
    status.carbon_assimilation = status.aPPFD / constants.J_to_umol * m.rue
    # aPPFD is in mol[PAR] plant⁻¹ d⁻¹, we need MJ[PAR] plant⁻¹ d⁻¹ first, and then use RUE
    # This gives carbon_assimilation in g CH2O-equivalent plant⁻¹ d⁻¹.
end
