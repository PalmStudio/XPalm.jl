"""
    DegreeDaysFTSW(TOpt1, TOpt2, TBase, TLim, threshold_ftsw_stress)
    DegreeDaysFTSW(TOpt1=25, TOpt2=30, TBase=15, TLim=40, threshold_ftsw_stress=0.3)

Compute thermal time from daily meteo data, corrected by FTSW

# Arguments

- `TOpt1`: starting optimal temperature for thermal time calculation (degree Celsius)
- `TOpt2`: ending optimal temperature for thermal time calculation (degree Celsius)
- `TBase`: Tbase temperature for thermal time calculation (degree Celsius)
- `TLim`: limit temperature for thermal time calculation (degree Celsius)
- `threshold_ftsw_stress`: threshold value under which we apply an FTSW stress
"""
struct DegreeDaysFTSW{T} <: AbstractThermal_TimeModel
    TOpt1::T
    TOpt2::T
    TBase::T
    TLim::T
    threshold_ftsw_stress::T
end


PlantSimEngine.inputs_(::DegreeDaysFTSW) = (ftsw=-Inf,)

PlantSimEngine.outputs_(::DegreeDaysFTSW) = (
    TEff=-Inf,
    TT_since_init=-Inf,
)

function DegreeDaysFTSW(;
    TOpt1=25.0,
    TOpt2=30.0,
    TBase=15.0,
    TLim=40.0,
    threshold_ftsw_stress=0.3
)
    DegreeDaysFTSW(TOpt1, TOpt2, TBase, TLim, threshold_ftsw_stress)
end

"""
Compute degree days corrected by FTSW

# Arguments

- `m`: DegreeDaysFTSW model

# Returns

- `TEff`: daily efficient temperature for plant growth (degree C days) 
"""
function PlantSimEngine.run!(m::DegreeDaysFTSW, models, status, meteo, constants, extra=nothing)

    Tmin = meteo.Tmin
    Tmax = meteo.Tmax

    if (Tmin >= Tmax)
        if (Tmin > m.TOpt1)
            status.TEff = m.TOpt1 - m.TBase
        else
            status.TEff = Tmin - m.TBase
        end
    else
        if (Tmin < m.TOpt1)
            V = ((min(m.TOpt1, Tmax) + Tmin) / 2 - m.TBase) / (m.TOpt1 - m.TBase)
        else
            V = 0
        end
        if (Tmax > m.TOpt2)
            W = (m.TLim - (Tmax + max(m.TOpt2, Tmin)) / 2) / (m.TLim - m.TOpt2)
        else
            W = 0
        end
        if (Tmax < m.TOpt1)
            S2 = 0
        else
            if (Tmax < m.TOpt2)
                S2 = Tmax - max(m.TOpt1, Tmin)
            else
                if (Tmin > m.TOpt2)
                    S2 = 0
                else
                    S2 = m.TOpt2 - max(m.TOpt1, Tmin)
                end
            end
        end
        m1 = V * (min(m.TOpt1, Tmax) - Tmin)
        m2 = W * (Tmax - max(Tmin, m.TOpt2))
        if (Tmax <= m.TBase)
            status.TEff = 0
        else
            if (Tmin >= m.TLim)
                status.TEff = 0
            else
                status.TEff = ((m1 + m2 + S2) / (Tmax - Tmin)) * (m.TOpt1 - m.TBase)
            end
            if (status.TEff < 0)
                status.TEff = 0
            end
        end
    end

    expansion_stress = status.ftsw > m.threshold_ftsw_stress ? 1 : status.ftsw / m.threshold_ftsw_stress
    status.TEff = status.TEff * expansion_stress
    # We apply an expansion stress to the thermal time based on FTSW:
    prevTT = PlantMeteo.prev_value(status, :TT_since_init, default=0.0)

    #! here we check if the previous value was -Inf because the leaf can appear at any day 
    #! since begining of the simulation, so at initialisation the previous value is -Inf
    if prevTT == -Inf
        prevTT = 0.0
    end

    status.TT_since_init = prevTT + status.TEff
end