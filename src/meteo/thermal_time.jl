
"""
    DailyDegreeDays(TOpt1, TOpt2, TBase, TLim)
    DailyDegreeDays(TOpt1=25, TOpt2=30, TBase=15, TLim=40)

Compute thermal time from daily meteo data

# Arguments

- `TOpt1`: starting optimal temperature for thermal time calculation (degree Celsius)
- `TOpt2`: ending optimal temperature for thermal time calculation (degree Celsius)
- `TBase`: Tbase temperature for thermal time calculation (degree Celsius)
- `TLim`: limit temperature for thermal time calculation (degree Celsius)


# Outputs
- `TEff`: daily efficient temperature for plant growth (degree C days) 

"""
struct DailyDegreeDays{T} <: AbstractThermal_TimeModel
    TOpt1::T
    TOpt2::T
    TBase::T
    TLim::T
end


PlantSimEngine.inputs_(::DailyDegreeDays) = NamedTuple()

PlantSimEngine.outputs_(::DailyDegreeDays) = (
    TEff=-Inf,
    TT_since_init=-Inf,
)

function DailyDegreeDays(;
    TOpt1=25.0,
    TOpt2=30.0,
    TBase=15.0,
    TLim=40.0
)
    DailyDegreeDays(promote(TOpt1, TOpt2, TBase, TLim)...)
end

function PlantSimEngine.run!(m::DailyDegreeDays, models, status, meteo, constants, extra=nothing)

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

    status.TT_since_init = prev_value(status, :TT_since_init, default=0.0) + status.TEff
end


function PlantSimEngine.run!(::DailyDegreeDays, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    scene = get_root(mtg)
    scene_status = PlantSimEngine.status(scene[:models])[rownumber(st)]
    st.TEff = scene_status.TEff
    prev_TT = prev_value(st, :TT_since_init, default=0.0)
    st.TT_since_init = prev_TT == -Inf ? 0.0 : prev_TT + st.TEff
end