"""
    ConstantRUEModel(rue)

Computes the `carbon_assimilation` using a constant radiation use efficiency (`rue`).

# Arguments

- `rue`: radiation use efficiency (gC MJ⁻¹)

# Inputs
- `aPPFD`: the absorbed Photosynthetic Photon Flux Density in mol[PAR] m[leaf]⁻² s⁻¹.

# Outputs
- `carbon_assimilation`: carbon offer from photosynthesis
"""
struct RUE_FTSW{T} <: AbstractCarbon_AssimilationModel
    rue::T
    threshold_ftsw::T
end

PlantSimEngine.inputs_(::RUE_FTSW) = (aPPFD=-Inf, ftsw=-Inf)
PlantSimEngine.outputs_(::RUE_FTSW) = (carbon_assimilation=-Inf,)

function PlantSimEngine.run!(m::RUE_FTSW, models, status, meteo, constants, extra=nothing)
    photo_reduc = status.ftsw > m.threshold_ftsw ? 1.0 : status.ftsw / m.threshold_ftsw
    status.carbon_assimilation = status.aPPFD / constants.J_to_umol * m.rue * photo_reduc
    # aPPFD is in mol[PAR] plant⁻¹ d⁻¹, we need MJ[PAR] plant⁻¹ d⁻¹ first, and then use RUE
    # This gives carbon_assimilation in gC plant⁻¹ d⁻¹
end