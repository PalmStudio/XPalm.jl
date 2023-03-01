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
struct FTSW{T} <: SoilModel
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
    depth=-Inf,
    ET0=-Inf, #potential evapotranspiration
    tree_ei=-Inf, # light interception efficiency (ei=1-exp(-kLAI))
    qte_H2O_C1=-Inf, # quantity of water in C1 compartment
    qte_H2O_Vap=-Inf, # quantity of water in evaporative compartment
)

PlantSimEngine.outputs_(::FTSW) =
    (
        qte_H2O_C1=-Inf,
        qte_H2O_Vap=-Inf,
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

- `TailleC1`: size of the evapotranspirable water layer in the first soil layer (mm)
- `TailleVap`: size of the evaporative layer within the first layer (mm)
- `TailleC1moinsVap`: size of the transpirable layer within the first layer (TailleC1-TailleVap)
- `TailleC2`: size of the transpirable water layer in the first soil layer (mm)
- `TailleC`: size of transpirable soil water (mm) (TailleC2 + TailleC1moinsVap)
"""
function compute_compartment_size(m, root_depth)

    Taille_WP = m.H_WP * m.Z1
    # Size of the evaporative component of the first layer:
    TailleVap = 0.5 * Taille_WP
    # NB: the 0.5 is because water can still evaporate below the wilting point
    # in the first layer, considered at 0.5 * H_WP. 
    #! replace 0.5 * m.H_WP by a parameter

    # Size of the evapotranspirable water layer in the first soil layer:
    if (root_depth > m.Z1)
        TailleC1 = m.H_FC * m.Z1 - (Taille_WP - TailleVap)
        # m.H_FC * m.Z1 -> size of the first layer at field capacity
        # (Taille_WP - TailleVap) -> size of the first layer that will never evapotranspirate
        # TailleC1 -> size of the first layer that can evapotranspirate
    else
        TailleC1 = m.H_FC * root_depth - TailleVap
    end
    TailleC1moinsVap = TailleC1 - TailleVap


    if (root_depth > m.Z2 + m.Z1)
        TailleC2 = (m.H_FC - m.H_WP) * m.Z2
    else
        TailleC2 = max(0.0, (m.H_FC - m.H_WP) * (root_depth - m.Z1))
        TailleC = TailleC2 + TailleC1moinsVap
    end

    return TailleC1, TailleVap, TailleC1moinsVap, TailleC2, TailleC
end

function soil_init_default(m::FTSW, root_depth)
    TailleC1, TailleVap, TailleC1moinsVap, TailleC2, TailleC = compute_compartment_size(m, root_depth)

    TailleC1 = (m.H_FC - m.H_WP_Z1) * m.Z1
    TailleVap = m.H_WP_Z1 * m.Z1
    TailleC1moinsVap = TailleC1 - TailleVap
    TailleC2 = (m.H_FC - m.H_WP) * m.Z2
    TailleC = TailleC2 + TailleC1 - TailleVap
    a_C1 = min(TailleC1, (m.H_0 - m.H_WP_Z1) * m.Z1)
    qte_H2O_C1 = max(0.0, a_C1)
    a_vap = min(TailleVap, (m.H_0 - m.H_WP_Z1) * m.Z1)
    qte_H2O_Vap = max(0.0, a_vap)
    a_C2 = min(TailleC2, (m.H_0 - m.H_WP) * m.Z2)
    qte_H2O_C2 = max(0.0, a_C2)
    a_C = qte_H2O_C1 + qte_H2O_C2 - qte_H2O_Vap
    qte_H2O_C = max(0.0, a_C)
    a_C1moinsV = qte_H2O_C1 - qte_H2O_Vap
    qte_H2O_C1moinsVap = max(0.0, a_C1moinsV)
    qte_H2O_C1_Racines = max(0.0, qte_H2O_C1 * racines_TailleC1 / TailleC1)
    qte_H2O_Vap_Racines = max(0.0, qte_H2O_Vap * racines_TailleVap / TailleVap)
    qte_H2O_C2_Racines = max(0.0, qte_H2O_C2 * racines_TailleC2 / TailleC2)
    qte_H2O_C_Racines = max(0.0, qte_H2O_C * racines_TailleC / TailleC)
    qte_H2O_C1moinsVap_Racines = max(0.0, qte_H2O_C1moinsVap * racines_TailleC1moinsVap / TailleC1moinsVap)
    FractionC1 = 0
    FractionC2 = 0
    FractionC = 0
    FractionC1Racine = 0
    FractionC2Racine = 0
    ftsw = 0.5
    FractionC1moinsVapRacine = 0
    compute_fraction()
    EvapMax = 0
    Transp_Max = 0
    pluie_efficace = 0
    Evap = 0
    EvapC1moinsVap = 0
    EvapVap = 0
    Transpi = 0
    TranspiC2 = 0
    TranspiC1moinsVap = 0
    a_C1moinsVap_Racines = 0
    a_Vap_Racines = 0
end

function soil_model!_(::FTSW, models, status, meteo, constants, extra=nothing)
    rain = meteo.Precipitations

    EvapMax = (1 - status.tree_ei) * status.ET0 * models.soil_model.KC
    Transp_Max = status.tree_ei * status.ET0 * models.soil_model.KC

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

    # fill compartment with rain
    mem_qte_H2O_C1 = status.qte_H2O_C1
    mem_qte_H2O_Vap = status.qte_H2O_Vap

    if (status.qte_H2O_Vap + rain_effective) >= TailleVap
        status.qte_H2O_Vap = TailleVap
        rain_remain = rain_effective - TailleVap
        if (qte_H2O_C1moinsVap + (rain_remain + mem_qte_H2O_Vap)) >= TailleC1moinsVap
            qte_H2O_C1moinsVap = TailleC1moinsVap
            qte_H2O_C1 = qte_H2O_C1moinsVap + qte_H2O_Vap
            rain_remain = rain_effective - TailleC1
            if (status.qte_H2O_C2 + mem_qte_H2O_C1 + rain_remain) >= TailleC2
                status.qte_H2O_C2 = TailleC2
                rain_remain = rain_effective - TailleC1 - TailleC2
            else
                qte_H2O_C2 += mem_qte_H2O_C1 + rain_remain
                rain_remain = 0
            end
        else
            qte_H2O_C1moinsVap += rain_remain + mem_qte_H2O_Vap
            qte_H2O_C1 = qte_H2O_C1moinsVap + qte_H2O_Vap
            rain_remain = 0
        end
    else
        qte_H2O_Vap += rain_effective
        qte_H2O_C1 = qte_H2O_Vap + qte_H2O_C1moinsVap
        rain_remain = 0
    end
    qte_H2O_C = qte_H2O_C1moinsVap + qte_H2O_C2

    ## RP: this part of the code is incomprehensible, exactly the same calculation as above 
    # above, again using the rains that have already been used...
    # moreover the size of the compartments is already defined by the root depth...
    ## I take back and simplify the code, cf FTSW raph


    mem_qte_H2O_C1_Racines = qte_H2O_C1_Racines
    mem_qte_H2O_Vap_Racines = qte_H2O_Vap_Racines

    if ((qte_H2O_Vap_Racines + rain_effective) >= racines_TailleVap)
        qte_H2O_Vap_Racines = racines_TailleVap
        if ((qte_H2O_C1moinsVap_Racines + (rain_effective - racines_TailleVap + mem_qte_H2O_Vap_Racines)) >= racines_TailleC1moinsVap)
            qte_H2O_C1moinsVap_Racines = racines_TailleC1moinsVap
            qte_H2O_C1_Racines = qte_H2O_C1moinsVap_Racines + qte_H2O_Vap_Racines
            if ((qte_H2O_C2_Racines + mem_qte_H2O_C1_Racines + rain_effective - racines_TailleC1) >= racines_TailleC2)
                qte_H2O_C2_Racines = racines_TailleC2
            else
                qte_H2O_C2_Racines += mem_qte_H2O_C1_Racines + rain_effective - racines_TailleC1
            end
        else
            qte_H2O_C1moinsVap_Racines += rain_effective - racines_TailleVap + mem_qte_H2O_Vap_Racines
            qte_H2O_C1_Racines = qte_H2O_C1moinsVap_Racines + qte_H2O_Vap_Racines
        end
    else
        qte_H2O_Vap_Racines += rain_effective
        qte_H2O_C1_Racines = qte_H2O_C1moinsVap_Racines + qte_H2O_Vap_Racines
    end
    qte_H2O_C_Racines = qte_H2O_C1moinsVap_Racines + qte_H2O_C2_Racines

    compute_fraction!(status)

    #Evap = EvapMax * (FractionC1 > models.soil_model.TRESH_EVAP ? 1 : FractionC1 / models.soil_model.TRESH_EVAP)
    Evap = EvapMax * KS(FractionC1, models.soil_model.TRESH_EVAP)
    if qte_H2O_C1moinsVap - Evap >= 0
        qte_H2O_C1moinsVap += -Evap
        EvapC1moinsVap = Evap
        EvapVap = 0
    else
        EvapC1moinsVap = qte_H2O_C1moinsVap
        qte_H2O_C1moinsVap = 0
        EvapVap = Evap - EvapC1moinsVap
        qte_H2O_Vap += -EvapVap
    end
    qte_H2O_C1 = qte_H2O_C1moinsVap + qte_H2O_Vap
    qte_H2O_C = qte_H2O_C1 + qte_H2O_C2 - qte_H2O_Vap

    a_C1moinsVap_Racines = qte_H2O_C1moinsVap_Racines - EvapC1moinsVap * racines_TailleC1moinsVap / TailleC1moinsVap
    qte_H2O_C1moinsVap_Racines = max(0.0, a_C1moinsVap_Racines)
    a_Vap_Racines = qte_H2O_Vap_Racines - EvapVap * racines_TailleVap / TailleVap
    qte_H2O_Vap_Racines = max(0.0, a_Vap_Racines)
    qte_H2O_C1_Racines = qte_H2O_Vap_Racines + qte_H2O_C1moinsVap_Racines
    qte_H2O_C_Racines = qte_H2O_C2_Racines + qte_H2O_C1moinsVap_Racines

    compute_fraction!(status)

    # Transpi = Transp_Max * (ftsw > models.soil_model.TRESH_FTSW_TRANSPI ? 1 : ftsw / models.soil_model.TRESH_FTSW_TRANSPI)
    Transpi = Transp_Max * KS(models.soil_model.TRESH_FTSW_TRANSPI, ftsw)

    if qte_H2O_C2_Racines > 0
        TranspiC2 = min(Transpi * (qte_H2O_C2_Racines / (qte_H2O_C2_Racines + qte_H2O_C1moinsVap_Racines)), qte_H2O_C2_Racines)
    else
        TranspiC2 = 0
    end

    if qte_H2O_C1moinsVap_Racines > 0
        TranspiC1moinsVap = min(Transpi * (qte_H2O_C1moinsVap_Racines / (qte_H2O_C2_Racines + qte_H2O_C1moinsVap_Racines)), qte_H2O_C1moinsVap_Racines)
    else
        TranspiC1moinsVap = 0
    end

    qte_H2O_C1moinsVap_Racines += -TranspiC1moinsVap
    qte_H2O_C2_Racines += -TranspiC2
    qte_H2O_C_Racines = qte_H2O_C2_Racines + qte_H2O_C1moinsVap_Racines
    qte_H2O_C1_Racines = qte_H2O_Vap_Racines + qte_H2O_C1moinsVap_Racines

    qte_H2O_C1moinsVap += -TranspiC1moinsVap
    qte_H2O_C2 += -TranspiC2
    qte_H2O_C = qte_H2O_C2 + qte_H2O_C1moinsVap
    qte_H2O_C1 = qte_H2O_Vap + qte_H2O_C1moinsVap

    compute_fraction!(status)
end



function compute_fraction!(status)
    FractionC1 = status.qte_H2O_C1 / TailleC1
    if TailleC2 > 0
        FractionC2 = status.qte_H2O_C2 / TailleC2
    else
        FractionC2 = 0
    end
    FractionC = status.qte_H2O_C / TailleC
    FractionC1Racine = status.qte_H2O_C1_Racines / racines_TailleC1
    if racines_TailleC2 > 0
        FractionC2Racine = status.qte_H2O_C2_Racines / racines_TailleC2
    else
        FractionC2Racine = 0
    end
    status.ftsw = status.qte_H2O_C_Racines / racines_TailleC
    FractionC1moinsVapRacine = qte_H2O_C1moinsVap_Racines / racines_TailleC1moinsVap
end