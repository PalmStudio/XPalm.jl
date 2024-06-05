"""
    ConstantRUEModel(rue)

Computes the `carbon_assimilation` using a constant radiation use efficiency (`rue`).

# Arguments

- `rue`: radiation use efficiency (gC MJ⁻¹)
"""
struct ConstantRUEModel{T} <: AbstractCarbon_AssimilationModel
    rue::T
end

PlantSimEngine.inputs_(::ConstantRUEModel) = (aPPFD_plant=-Inf,)
PlantSimEngine.outputs_(::ConstantRUEModel) = (carbon_assimilation=-Inf,)

function PlantSimEngine.run!(m::ConstantRUEModel, models, status, meteo, constants, extra=nothing)
    status.carbon_assimilation = status.aPPFD_plant / constants.J_to_umol * m.rue
    # aPPFD is in mol[PAR] plant⁻¹ d⁻¹, we need MJ[PAR] plant⁻¹ d⁻¹ first, and then use RUE
    # This gives carbon_assimilation in gC plant⁻¹ d⁻¹
end