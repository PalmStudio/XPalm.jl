function computeTEff(Tmin, Tmax, TOpt1, TOpt2, TBase, TLim)
    if (Tmin >= Tmax)
        if (Tmin > TOpt1)
            TEff = TOpt1 - TBase
        else
            TEff = Tmin - TBase
        end
    else
        if (Tmin < TOpt1)
            V = ((min(TOpt1, Tmax) + Tmin) / 2 - TBase) / (TOpt1 - TBase)
        else
            V = 0
        end
        if (Tmax > TOpt2)
            W = (TLim - (Tmax + max(TOpt2, Tmin)) / 2) / (TLim - TOpt2)
        else
            W = 0
        end
        if (Tmax < TOpt1)
            S2 = 0
        else
            if (Tmax < TOpt2)
                S2 = Tmax - max(TOpt1, Tmin)
            else
                if (Tmin > TOpt2)
                    S2 = 0
                else
                    S2 = TOpt2 - max(TOpt1, Tmin)
                end
            end
        end
        m1 = V * (min(TOpt1, Tmax) - Tmin)
        m2 = W * (Tmax - max(Tmin, TOpt2))
        if (Tmax <= TBase)
            TEff = 0
        else
            if (Tmin >= TLim)
                TEff = 0
            else
                TEff = ((m1 + m2 + S2) / (Tmax - Tmin)) * (TOpt1 - TBase)
            end
            if (TEff < 0)
                TEff = 0
            end
        end
    end
end