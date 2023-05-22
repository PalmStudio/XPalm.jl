"""
LAIGrowth(LAI_max, LAI_growth_rate,TRESH_FTSW_SLOW_LAI)
LAIGrowth(LAI_max=5.0, LAI_growth_rate=3*10^-5,TRESH_FTSW_SLOW_LAI=0.5)

Compute LAI growth depending on thermal time and FTSW

# Arguments

- `LAI_max`: maximum LAI (m2.m-2)
- `LAI_growth_rate`: increment of LAI with thermal time
- `TRESH_FTSW_SLOW_LAI`: ftsw treshold below which LAI growth is reduced (unitless [0:1])

"""
struct LAIGrowth{T} <: AbstractLai_DynamicModel
    LAI_max::T
    LAI_growth_rate::T
    TRESH_FTSW_SLOW_LAI::T
end


PlantSimEngine.inputs_(::LAIGrowth) = (
    ftsw=-Inf, # fraction of transpirable soil water (unitless [0:1])
    TEff=-Inf, # daily efficient temperature for plant growth (degree C days) 
)

PlantSimEngine.outputs_(::LAIGrowth) = (
    LAI=-Inf, # leaf area index (m2 m-2)
)


function LAIGrowth(;
    LAI_max=5.0,
    LAI_growth_rate=3 * 10^-5,
    TRESH_FTSW_SLOW_LAI=0.5
)
    LAIGrowth(LAI_max, LAI_growth_rate, TRESH_FTSW_SLOW_LAI)
end


"""
Compute LAI growth

# Arguments

- `m`: LAI growth model
- ftsw:  fraction of transpirable soil water (unitless [0:1])
- TEff:  daily efficient temperature for plant growth (degree C days) 

# Returns

- `LAI`: root depth (cm)
"""
function PlantSimEngine.run!(m::LAIGrowth, models, status, meteo, constants, extra=nothing)

    ftsw = PlantMeteo.prev_value(status, :ftsw; default=status.ftsw)
    status.LAI = PlantMeteo.prev_value(status, :LAI; default=status.LAI)

    if (ftsw > m.TRESH_FTSW_SLOW_LAI)
        coef_water_stress = 1
    else
        coef_water_stress = ftsw / m.TRESH_FTSW_SLOW_LAI
    end

    if (status.LAI + coef_water_stress * m.LAI_growth_rate * status.TEff > m.LAI_max)
        status.LAI = m.LAI_max
    else
        status.LAI += coef_water_stress * m.LAI_growth_rate * status.TEff
    end
end
