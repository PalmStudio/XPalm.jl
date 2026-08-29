"""
    RUE_FTSW(rue, threshold_ftsw)

Computes the `carbon_assimilation` using a constant radiation use efficiency (`rue`).

# Arguments

- `rue`: gross radiation use efficiency (g CH2O-equivalent MJ⁻¹)
- `threshold_ftsw`: unitless FTSW threshold below which RUE is reduced.

# Inputs
- `aPPFD`: absorbed PAR in mol[photon] plant⁻¹ d⁻¹.

# Outputs
- `carbon_assimilation`: gross assimilate production
  (g CH2O-equivalent plant⁻¹ d⁻¹)
"""
struct RUE_FTSW{T} <: AbstractCarbon_AssimilationModel
    rue::T
    threshold_ftsw::T
end

PlantSimEngine.inputs_(::RUE_FTSW) = (
    aPPFD=PlantSimEngine.Required(Real),
    ftsw=PlantSimEngine.Default(1.0),
)
PlantSimEngine.outputs_(::RUE_FTSW) = (carbon_assimilation=-Inf,)
PlantSimEngine.variable_contracts_(::RUE_FTSW) = (
    aPPFD=_PLANT_DAILY_PAR_PHOTONS,
    carbon_assimilation=_DAILY_CH2O_EQUIVALENT_FLOW,
)

function PlantSimEngine.run!(m::RUE_FTSW, status, environment, constants, context=nothing)
    photo_reduc = status.ftsw > m.threshold_ftsw ? 1.0 : status.ftsw / m.threshold_ftsw
    status.carbon_assimilation = status.aPPFD / constants.J_to_umol * m.rue * photo_reduc
    # aPPFD is in mol[PAR] plant⁻¹ d⁻¹, we need MJ[PAR] plant⁻¹ d⁻¹ first, and then use RUE
    # This gives carbon_assimilation in g CH2O-equivalent plant⁻¹ d⁻¹.
end
