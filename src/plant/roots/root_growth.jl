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

PlantSimEngine.outputs_(::RootGrowthFTSW) = (
    root_depth=-Inf, # root depth (cm)
)

function RootGrowthFTSW(;
    ini_root_depth,
    ROOTS_GROWTH_DEPTH=0.3,
    TRESH_FTSW_SLOW_ROOTS=0.2
)
    RootGrowthFTSW(ini_root_depth, ROOTS_GROWTH_DEPTH, TRESH_FTSW_SLOW_ROOTS)
end

PlantSimEngine.dep(::RootGrowthFTSW) = (soil_water=AbstractFTSWModel,) # This model must return a value for ftsw, Z1 and Z2

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

    st.root_depth = prev_value(st, :root_depth; default=m.ini_root_depth)

    if (st.ftsw > m.TRESH_FTSW_SLOW_ROOTS)
        coef_water_stress = 1
    else
        coef_water_stress = st.ftsw / m.TRESH_FTSW_SLOW_ROOTS
    end

    if (st.root_depth + coef_water_stress * m.ROOTS_GROWTH_DEPTH * st.TEff > st.soil_depth)
        st.root_depth = st.soil_depth
    else
        st.root_depth += coef_water_stress * m.ROOTS_GROWTH_DEPTH * st.TEff
    end
end

# Called by the soil to get the root_depth:
function PlantSimEngine.run!(::RootGrowthFTSW, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    scene = get_root(mtg)
    timestep = rownumber(st)
    MultiScaleTreeGraph.traverse(scene, symbol="RootSystem") do roots
        st.root_depth = roots[:models].status[timestep].root_depth
    end
end