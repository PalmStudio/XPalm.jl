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
struct FTSW{T} <: SoilModel
    layers::Vector{FTSWLayer{T}}
end

struct FTSWLayer{T}
    thk::T # Thickness of the evaporative layer (m)
    h_0::T # Initial soil humidity (m3[H20] m-3[Soil])
    h_fc::T # Humidity at field capacity (m3[H20] m-3[Soil])
    h_wp::T # Humidity at wilting point (m3[H20] m-3[Soil])
    KC::T # cultural cefficient
    TRESH_EVAP::T  
    TRESH_FTSW_TRANSPI::T

end

# Method for instantiating an FTSW with vectors:
function FTSW(thk::T, h_0::T, h_fc::T, h_wp::T, KC::T) where {T<:Vector}
    length(thk) == length(h_0) == length(h_fc) == length(h_wp) == length(KC) ||
        throw(DimensionMismatch("All input vectors must have the same length"))

    layers = [FTSWLayer(thk[i], h_0[i], h_fc[i], h_wp[i], KC[i]) for i in eachindex(thk)]
    return FTSW(layers)
end

#' Coefficient of stress
#'
#' @param fillRate fill level of the compartment
#' @param tresh filling treshold of the  compartment below which there is a reduction in the flow
#'
#' @return
#' @export
#'
#' @examples
#' 
#### revision du code à faire par Rémi
function KS(fillRate,tresh)
    {
      ks=ifelse(test = fillRate >= tresh ,yes =  1,no=1/(tresh) * fillRate)
      return(ks)
    }

inputs_(::FTSW) = (
    depth=-Inf,
    ET0=-Inf, #potential evapotranspiration
    tree_ei=-Inf, #! light interception efficiency 
    qte_H2O_C1=-Inf, #! Ask Raph what is this variable
    qte_H2O_Vap=-Inf, #! Ask Raph what is this variable
)

outputs_(::FTSW) =
    (
        qte_H2O_C1=-Inf,
        qte_H2O_Vap=-Inf,
    )
# dep(::FTSW) = (test_prev=AbstractTestPrevModel,)

function soil_model!_(::FTSW, models, status, meteo::PlantMeteo.AbstractAtmosphere, constants=Constants())
    rain = meteo.Precipitations
    


   
    EvapMax = (1 - status.tree_ei) * status.ET0 * models.soil_model.KC
    Transp_Max = status.tree_ei * status.ET0 * models.soil_model.KC


    

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

    mem_qte_H2O_C1 = status.qte_H2O_C1
    mem_qte_H2O_Vap = status.qte_H2O_Vap
    if (status.qte_H2O_Vap + rain_effective) >= TailleVap
        status.qte_H2O_Vap = TailleVap
        if (qte_H2O_C1moinsVap + (rain_effective - TailleVap + mem_qte_H2O_Vap)) >= TailleC1moinsVap
            qte_H2O_C1moinsVap = TailleC1moinsVap
            qte_H2O_C1 = qte_H2O_C1moinsVap + qte_H2O_Vap
            if (status.qte_H2O_C2 + mem_qte_H2O_C1 + rain_effective - TailleC1) >= TailleC2
                status.qte_H2O_C2 = TailleC2
            else
                qte_H2O_C2 += mem_qte_H2O_C1 + rain_effective - TailleC1
            end
        else
            qte_H2O_C1moinsVap += rain_effective - TailleVap + mem_qte_H2O_Vap
            qte_H2O_C1 = qte_H2O_C1moinsVap + qte_H2O_Vap
        end
    else
        qte_H2O_Vap += rain_effective
        qte_H2O_C1 = qte_H2O_Vap + qte_H2O_C1moinsVap
    end
    qte_H2O_C = qte_H2O_C1moinsVap + qte_H2O_C2

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
    Evap = EvapMax * KS(FractionC1,models.soil_model.TRESH_EVAP )
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
   Transpi = Transp_Max * KS(models.soil_model.TRESH_FTSW_TRANSPI ,ftsw)
   
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