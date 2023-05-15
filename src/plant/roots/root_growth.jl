@process "root_growth" verbose = false

"""
    root_growth(TRESH_FTSW_SLOW_ROOTS, ROOTS_GROWTH_DEPTH, Z1, Z2)
    root_growth(TRESH_FTSW_SLOW_ROOTS=0.2, ROOTS_GROWTH_DEPTH=0.3, Z1=200, Z2=2000)

Compute root growth depending on thermal time and water stress (ftsw)

# Arguments

- `ROOTS_GROWTH_DEPTH`: root growth in depth (mm.degreeC days-1)
- `TRESH_FTSW_SLOW_ROOTS`: ftsw treshold below which roots growth is reduced (unitless [0:1])
- `Z1`: Thickness of the first soil layer (mm)
- `Z2`: Thickness of the second soil layer (mm)
"""
struct RootGrowth{T} <: AbstractRoot_GrowthModel
    ROOTS_GROWTH_DEPTH::T
    TRESH_FTSW_SLOW_ROOTS::T
    Z1::T
    Z2::T
end


PlantSimEngine.inputs_(::RootGrowth) = (
    ftsw=PrevValue(-Inf), # fraction of transpirable soil water (unitless [0:1])
    TEff=-Inf, # daily efficient temperature for plant growth (degree C days) 
)

PlantSimEngine.outputs_(::RootGrowth) = (
    root_depth=-Inf, # root depth (cm)
)


function RootGrowth(;
    ROOTS_GROWTH_DEPTH=0.3,
    TRESH_FTSW_SLOW_ROOTS=0.2,
    Z1=200.0,
    Z2=2000.0
)
    RootGrowth(ROOTS_GROWTH_DEPTH, TRESH_FTSW_SLOW_ROOTS, Z1, Z2)
end


"""
Compute root growth

# Arguments

- `m`: root growth model
- ftsw:  fraction of transpirable soil water (unitless [0:1])
- TEff:  daily efficient temperature for plant growth (degree C days) 

# Returns

- `root_depth`: root depth (cm)
"""
function PlantSimEngine.run!(m::RootGrowth, models, status, meteo, constants, extra=nothing)

    ftsw = PlantMeteo.prev_value(status, :ftsw; default=status.ftsw)
    status.root_depth = PlantMeteo.prev_value(status, :root_depth; default=status.root_depth)
    if (ftsw > m.TRESH_FTSW_SLOW_ROOTS)
        coef_water_stress = 1
    else
        coef_water_stress = ftsw / m.TRESH_FTSW_SLOW_ROOTS
    end

    if (status.root_depth + coef_water_stress * m.ROOTS_GROWTH_DEPTH * status.TEff > m.Z2 + m.Z1)
        status.root_depth = m.Z2 + m.Z1
    else
        status.root_depth += coef_water_stress * m.ROOTS_GROWTH_DEPTH * status.TEff
    end
end
