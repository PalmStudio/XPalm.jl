"""
    FTSW(layers::Vector{FTSWLayer})

Fraction of Transpirable Soil Water model.

Takes a vector of `FTSWLayer`s as input.

# Examples
    
```julia
soil = FTSW(
    [
        SoilLayer(0.1, 0.1, 0.2, 0.3),
        SoilLayer(0.2, 0.2, 0.3, 0.4),
    ]
)
``` 
"""
# struct FTSW{T} <: SoilModel
#     layers::Vector{FTSWLayer{T}}
# end

# struct FTSWLayer{T}
#     thk::T # Thickness of the evaporative layer (m)
#     h_0::T # Initial soil humidity (m3[H20] m-3[Soil])
#     h_fc::T # Humidity at field capacity (m3[H20] m-3[Soil])
#     h_wp::T # Humidity at wilting point (m3[H20] m-3[Soil])
#     KC::T # cultural cefficient
#     TRESH_EVAP::T
#     TRESH_FTSW_TRANSPI::T
# end

# Method for instantiating an FTSW with vectors:
# function FTSW(thk::T, h_0::T, h_fc::T, h_wp::T, KC::T) where {T<:Vector}
#     length(thk) == length(h_0) == length(h_fc) == length(h_wp) == length(KC) ||
#         throw(DimensionMismatch("All input vectors must have the same length"))

#     layers = [FTSWLayer(thk[i], h_0[i], h_fc[i], h_wp[i], KC[i]) for i in eachindex(thk)]
#     return FTSW(layers)
# end

@process Soil


"""
    FTSW(;H_FC=0.23, H_WP_Z1=0.05, Z1=200, H_WP=0.1, Z2=2000, H_0=0.15, KC=1, TRESH_EVAP, TRESH_FTSW_TRANSPI)

Fraction of Transpirable Soil Water model.

# Arguments

- `H_FC`: Humidity at field capacity (g[H20] g[Soil])
- `H_WP_Z1`: Humidity at wilting point (g[H20] g[Soil]) for the first layer
- `Z1`: Thickness of the first layer (mm)
- `H_WP`: Humidity at wilting point (g[H20] g[Soil]) for the second layer
- `Z2`: Thickness of the second layer (mm)
- `H_0`: Initial soil humidity (g[H20] g[Soil])
- `KC`: cultural coefficient (unitless)
- `TRESH_EVAP`: fraction of water content in the evaporative layer below which evaporation is reduced (g[H20] g[Soil])
- `TRESH_FTSW_TRANSPI`: FTSW treshold below which transpiration is reduced (g[H20] g[Soil])
"""
struct FTSW{T} <: AbstractSoilModel
    H_FC
    H_WP_Z1
    Z1
    H_WP
    Z2
    H_0
    KC
    TRESH_EVAP
    TRESH_FTSW_TRANSPI
end

function FTSW(;
    H_FC=0.23,
    H_WP_Z1=0.05,
    Z1=200,
    H_WP=0.1,
    Z2=2000,
    H_0=0.15,
    KC=1,
    TRESH_EVAP=0.5,
    TRESH_FTSW_TRANSPI=0.5
)
    FTSW(H_FC, H_WP_Z1, Z1, H_WP, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI)
end

PlantSimEngine.inputs_(::FTSW) = (
    root_depth=-Inf,
    ET0=-Inf, #potential evapotranspiration
    tree_ei=-Inf, # light interception efficiency (ei=1-exp(-kLAI))
    qty_H2O_Vap=-Inf, # quantity of water in evaporative compartment
    qty_H2O_C1=-Inf, # quantity of water in C1 compartment
    qty_H2O_C2=-Inf, # quantity of water in C2 compartment
    qty_H2O_C=-Inf, # quantity of water in C compartment
    ftsw=-Inf, # fraction of transpirable soil water
)

PlantSimEngine.outputs_(::FTSW) =
    (
        qty_H2O_Vap=-Inf,
        qty_H2O_C1=-Inf,
        qty_H2O_C2=-Inf,
        qty_H2O_C=-Inf,
        ftsw=-Inf,
    )
# dep(::FTSW) = (test_prev=AbstractTestPrevModel,)

"""
    KS(fillRate, tresh)

Coefficient of stress. 

# Arguments

- `fillRate`: fill level of the compartment
- `tresh`: filling treshold of the  compartment below which there is a reduction in the flow
"""
KS(fillRate, tresh) = fillRate >= tresh ? 1 : 1 / (tresh) * fillRate

"""
    compute_compartment_size(m, root_depth)

Compute the size of the layers of the FTSW model.

# Arguments

- `m`: FTSW model
- `root_depth`: depth of the root system

# Returns

- `SizeC1`: size of the evapotranspirable water layer in the first soil layer (mm)
- `SizeVap`: size of the evaporative layer within the first layer (mm)
- `SizeC1minusVap`: size of the transpirable layer within the first layer (SizeC1-SizeVap)
- `SizeC2`: size of the transpirable water layer in the first soil layer (mm)
- `SizeC`: size of transpirable soil water (mm) (SizeC2 + SizeC1minusVap)
"""

function compute_compartment_size(m, root_depth)

    Taille_WP = m.H_WP * m.Z1
    # Size of the evaporative component of the first layer:
    SizeVap = 0.5 * Taille_WP
    # NB: the 0.5 is because water can still evaporate below the wilting point
    # in the first layer, considered at 0.5 * H_WP. 
    #! replace 0.5 * m.H_WP by a parameter

    # Size of the evapotranspirable water layer in the first soil layer:
    if (root_depth > m.Z1)
        SizeC1 = m.H_FC * m.Z1 - (Taille_WP - SizeVap)
        # m.H_FC * m.Z1 -> size of the first layer at field capacity
        # (Taille_WP - SizeVap) -> size of the first layer that will never evapotranspirate
        # SizeC1 -> size of the first layer that can evapotranspirate
    else
        SizeC1 = m.H_FC * root_depth - SizeVap
    end
    SizeC1minusVap = SizeC1 - SizeVap


    if (root_depth > m.Z2 + m.Z1)
        SizeC2 = (m.H_FC - m.H_WP) * m.Z2
    else
        SizeC2 = max(0.0, (m.H_FC - m.H_WP) * (root_depth - m.Z1))
        SizeC = SizeC2 + SizeC1minusVap
    end

    return SizeC1, SizeVap, SizeC1minusVap, SizeC2, SizeC
end

function soil_init_default(m::FTSW, root_depth)
    SizeC1, SizeVap, SizeC1minusVap, SizeC2, SizeC = compute_compartment_size(m, root_depth)

    # SizeC1 = (m.H_FC - m.H_WP_Z1) * m.Z1
    # SizeVap = m.H_WP_Z1 * m.Z1
    # SizeC1minusVap = SizeC1 - SizeVap
    # SizeC2 = (m.H_FC - m.H_WP) * m.Z2
    # SizeC = SizeC2 + SizeC1 - SizeVap

    a_vap = min(SizeVap, (m.H_0 - m.H_WP_Z1) * m.Z1)
    qty_H2O_Vap = max(0.0, a_vap)

    a_C1moinsV = qty_H2O_C1 - qty_H2O_Vap
    qty_H2O_C1minusVap = max(0.0, a_C1moinsV)

    a_C1 = min(SizeC1, (m.H_0 - m.H_WP_Z1) * m.Z1)
    qty_H2O_C1 = max(0.0, a_C1)

    a_C2 = min(SizeC2, (m.H_0 - m.H_WP) * m.Z2)
    qty_H2O_C2 = max(0.0, a_C2)

    a_C = qty_H2O_C1 + qty_H2O_C2 - qty_H2O_Vap
    qty_H2O_C = max(0.0, a_C)

    status = Status(qty_H2O_C1=qty_H2O_C1, qty_H2O_C2=qty_H2O_C2, qty_H2O_C=qty_H2O_C)

    compute_fraction!(status)
end

function run!(::FTSW, models, status, meteo, constants, extra=nothing)
    rain = meteo.Rainfall

    EvapMax = (1 - status.tree_ei) * status.ET0 * m.KC
    Transp_Max = status.tree_ei * status.ET0 * m.KC

    # estim effective rain
    if (0.916 * rain - 0.589) < 0
        rain_soil = 0
    else
        rain_soil = (0.916 * rain - 0.589)
    end

    if (0.0713 * rain - 0.735) < 0
        stemflow = 0
    else
        stemflow = (0.0713 * rain - 0.735)
    end

    rain_effective = rain_soil + stemflow

    # balance after rain
    mem_qty_H2O_C1 = status.qty_H2O_C1
    mem_qty_H2O_Vap = status.qty_H2O_Vap

    if (status.qty_H2O_Vap + rain_effective) >= SizeVap
        status.qty_H2O_Vap = SizeVap # evaporative compartment is full
        rain_remain = rain_effective - SizeVap
        if (status.qty_H2O_C1minusVap + (rain_remain + mem_qty_H2O_Vap)) >= SizeC1minusVap
            status.qty_H2O_C1minusVap = SizeC1minusVap # Transpirative compartment in the first layer is full
            status.qty_H2O_C1 = status.qty_H2O_C1minusVap + status.qty_H2O_Vap
            rain_remain = rain_effective - SizeC1
            if (status.qty_H2O_C2 + mem_qty_H2O_C1 + rain_remain) >= SizeC2
                status.qty_H2O_C2 = SizeC2 # Transpirative compartment in the second layer is full
                rain_remain = rain_effective - SizeC1 - SizeC2
            else
                status.qty_H2O_C2 += mem_qty_H2O_C1 + rain_remain - SizeC1
                rain_remain = 0
            end
        else
            qty_H2O_C1minusVap += rain_remain + mem_qty_H2O_Vap
            status.qty_H2O_C1 = qty_H2O_C1minusVap + qty_H2O_Vap
            rain_remain = 0
        end
    else
        qty_H2O_Vap += rain_effective
        status.qty_H2O_C1 = qty_H2O_Vap + qty_H2O_C1minusVap
        rain_remain = 0
    end
    status.qty_H2O_C = qty_H2O_C1minusVap + qty_H2O_C2

    compute_fraction!(status)

    # balance after evaporation
    Evap = EvapMax * KS(FractionC1, m.TRESH_EVAP)

    if qty_H2O_C1minusVap - Evap >= 0 # first evaporation on the evapotranspirative compartment
        qty_H2O_C1minusVap += -Evap
        EvapC1minusVap = Evap
        EvapVap = 0
    else
        EvapC1minusVap = qty_H2O_C1minusVap # then evaporation only on the evaporative compartment
        qty_H2O_C1minusVap = 0
        EvapVap = Evap - EvapC1minusVap
        qty_H2O_Vap += -EvapVap
    end
    status.qty_H2O_C1 = qty_H2O_C1minusVap + qty_H2O_Vap
    status.qty_H2O_C = status.qty_H2O_C1 + status.qty_H2O_C2 - qty_H2O_Vap


    compute_fraction!(status)

    # balance after transpiration
    Transpi = Transp_Max * KS(m.TRESH_FTSW_TRANSPI, ftsw)

    if status.qty_H2O_C2 > 0
        TranspiC2 = min(Transpi * (qty_H2O_C2 / (qty_H2O_C2 + qty_H2O_C1minusVap)), qty_H2O_C2)
    else
        TranspiC2 = 0
    end

    if qty_H2O_C1minusVap > 0
        TranspiC1minusVap = min(Transpi * (qty_H2O_C1minusVap / (qty_H2O_C2 + qty_H2O_C1minusVap)), qty_H2O_C1minusVap)
    else
        TranspiC1minusVap = 0
    end

    qty_H2O_C1minusVap += -TranspiC1minusVap
    status.qty_H2O_C2 += -TranspiC2
    qty_H2O_C = qty_H2O_C2 + qty_H2O_C1minusVap
    qty_H2O_C1 = qty_H2O_Vap + qty_H2O_C1minusVap

    compute_fraction!(status)
end


function compute_fraction!(status)
    FractionC1 = status.qty_H2O_C1 / SizeC1
    if SizeC2 > 0
        FractionC2 = status.qty_H2O_C2 / SizeC2
    else
        FractionC2 = 0
    end
    ftsw = status.qty_H2O_C / SizeC
    return FractionC1, FractionC2, ftsw
end