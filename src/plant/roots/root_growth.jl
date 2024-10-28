"""
RootGrowthFTSW(TRESH_FTSW_SLOW_ROOTS, ROOTS_GROWTH_DEPTH, Z1, Z2)
RootGrowthFTSW(TRESH_FTSW_SLOW_ROOTS=0.2, ROOTS_GROWTH_DEPTH=0.3, Z1=200, Z2=2000)

Compute root growth depending on thermal time and water stress (ftsw)

# Arguments

- `ini_root_depth`: initial root depth (mm)
- `ROOTS_GROWTH_DEPTH`: root growth in depth (mm.degreeC days-1)
- `TRESH_FTSW_SLOW_ROOTS`: ftsw treshold below which roots growth is reduced (unitless [0:1])

The model as a dependency on an `AbstractFTSWModel` that must return a value for `ftsw`, and `soil_depth`.
"""
struct RootGrowthFTSW{T} <: AbstractRoot_GrowthModel
    ini_root_depth::T
    ROOTS_GROWTH_DEPTH::T
    TRESH_FTSW_SLOW_ROOTS::T
end

PlantSimEngine.inputs_(::RootGrowthFTSW) = (
    ftsw=-Inf,
    TEff=-Inf, # daily efficient temperature for plant growth (degree C days)
    soil_depth=-Inf, # soil depth (cm)
)

PlantSimEngine.outputs_(m::RootGrowthFTSW) = (
    root_depth=m.ini_root_depth, # root depth (cm)
)

function RootGrowthFTSW(;
    ini_root_depth,
    ROOTS_GROWTH_DEPTH=0.3,
    TRESH_FTSW_SLOW_ROOTS=0.2
)
    RootGrowthFTSW(ini_root_depth, ROOTS_GROWTH_DEPTH, TRESH_FTSW_SLOW_ROOTS)
end

"""
Compute root growth

# Arguments

- `m`: root growth model
- ftsw:  fraction of transpirable soil water (unitless [0:1])
- TEff:  daily efficient temperature for plant growth (degree C days) 

# Outputs

- `root_depth`: root depth (cm)
"""
function PlantSimEngine.run!(m::RootGrowthFTSW, models, st, meteo, constants, extra=nothing)

    if st.ftsw > m.TRESH_FTSW_SLOW_ROOTS
        coef_water_stress = 1.0
    elseif st.ftsw > 0.0
        coef_water_stress = st.ftsw / m.TRESH_FTSW_SLOW_ROOTS
    else
        coef_water_stress = 0.0
    end

    # st.root_depth == 100 || st.root_depth == -Inf && @show st.root_depth st.ftsw
    if (st.root_depth + coef_water_stress * m.ROOTS_GROWTH_DEPTH * st.TEff > st.soil_depth)
        st.root_depth = st.soil_depth
    else
        st.root_depth += coef_water_stress * m.ROOTS_GROWTH_DEPTH * st.TEff
    end
end
