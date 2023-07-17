"""
    ConstantRUEModel(rue)

Computes the `carbon_assimilation` using a constant radiation use efficiency (`rue`).

# Arguments

- `rue`: radiation use efficiency (g.MJ-1)


# Examples 

```jldoctest

```

"""
struct ConstantRUEModel{T} <: AbstractCarbon_AssimilationModel
    rue::T
end

PlantSimEngine.inputs_(::ConstantRUEModel) = (aPPFD=-Inf,)
PlantSimEngine.outputs_(::ConstantRUEModel) = (carbon_assimilation=-Inf,)

function PlantSimEngine.run!(m::ConstantRUEModel, models, status, meteo, constants, extra=nothing)
    status.carbon_assimilation = status.aPPFD / constants.J_to_umol * m.rue
    # aPPFD is in mol d-1 plant-1, we need MJ d-1 plant-1 first, and then use RUE
end