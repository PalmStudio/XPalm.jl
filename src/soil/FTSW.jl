"""
    FTSW{O}(
        ini_root_depth::T
        H_FC::T
        H_WP_Z1::T
        Z1::T
        H_WP_Z2::T
        Z2::T
        H_0::T
        KC::T
        TRESH_EVAP::T
        TRESH_FTSW_TRANSPI::T
        ini_qty_H2O_Vap::T
        ini_qty_H2O_C1::T
        ini_qty_H2O_C1minusVap::T
        ini_qty_H2O_C2::T
        ini_qty_H2O_C::T
    )

Fraction of Transpirable Soil Water model.

Note that there is also a method for `FTSW` that takes an organ type as type, *e.g.* `FTSW{Leaf}(ini_root_depth = 200.0)`.

# Arguments

- `ini_root_depth`: root depth at initialization (mm)
- `H_FC`: Humidity at field capacity (g[H20] g[Soil])
- `H_WP_Z1`: Humidity at wilting point (g[H20] g[Soil]) for the first layer
- `Z1`: Thickness of the first layer (mm)
- `H_WP_Z2`: Humidity at wilting point (g[H20] g[Soil]) for the second layer
- `Z2`: Thickness of the second layer (mm)
- `H_0`: Initial soil humidity (g[H20] g[Soil])
- `KC`: cultural coefficient (unitless)
- `TRESH_EVAP`: fraction of water content in the evaporative layer below which evaporation is reduced (g[H20] g[Soil])
- `TRESH_FTSW_TRANSPI`: FTSW treshold below which transpiration is reduced (g[H20] g[Soil])
"""
struct FTSW{O,T} <: AbstractFTSWModel where {O,T} # O: type of organ, T: type of the values
    ini_root_depth::T   # root depth at initialization (mm)
    H_FC::T
    H_WP_Z1::T
    Z1::T
    H_WP_Z2::T
    Z2::T
    H_0::T
    KC::T
    TRESH_EVAP::T
    TRESH_FTSW_TRANSPI::T
    ini_qty_H2O_Vap::T  # quantity of water in evaporative compartment
    ini_qty_H2O_C1::T   # quantity of water in C1 compartment
    ini_qty_H2O_C1minusVap::T
    ini_qty_H2O_C2::T   # quantity of water in C2 compartment
    ini_qty_H2O_C::T    # quantity of water in C compartment
end

function FTSW{O}(;
    ini_root_depth,
    H_FC=0.23,
    H_WP_Z1=0.05,
    Z1=200.0,
    H_WP_Z2=0.05,
    Z2=2000.0,
    H_0=0.15,
    KC=1.0,
    TRESH_EVAP=0.5,
    TRESH_FTSW_TRANSPI=0.5
) where {O}
    vals = promote(ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI)
    FTSW{O,typeof(vals[1])}(vals...)
end

function FTSW(;
    ini_root_depth,
    H_FC=0.23,
    H_WP_Z1=0.05,
    Z1=200.0,
    H_WP_Z2=0.05,
    Z2=2000.0,
    H_0=0.15,
    KC=1.0,
    TRESH_EVAP=0.5,
    TRESH_FTSW_TRANSPI=0.5
)
    vals = promote(ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI)
    FTSW{typeof(vals[1]),typeof(vals[1])}(vals...)
end

function FTSW{O,T}(ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI) where {O,T}
    soil = FTSW{O,T}(ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI, 0.0, 0.0, 0.0, 0.0, 0.0)
    init = soil_init_default(soil)
    FTSW{O,T}(
        ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI,
        init.qty_H2O_Vap, init.qty_H2O_C1, init.qty_H2O_C1minusVap, init.qty_H2O_C2, init.qty_H2O_C
    )
end

PlantSimEngine.inputs_(::FTSW) = (
    root_depth=-Inf,
    ET0=-Inf, #potential evapotranspiration
    aPPFD=-Inf, # light intercepted by the crop
)

PlantSimEngine.outputs_(::FTSW) = (
    qty_H2O_Vap=-Inf,  # quantity of water in evaporative compartment
    qty_H2O_C1=-Inf,   # quantity of water in C1 compartment
    qty_H2O_C1minusVap=-Inf,
    qty_H2O_C2=-Inf,   # quantity of water in C2 compartment
    qty_H2O_C=-Inf,    # quantity of water in C compartment
    FractionC1=-Inf,
    FractionC2=-Inf,
    SizeC1=-Inf,
    SizeC2=-Inf,
    SizeC=-Inf,
    SizeVap=-Inf,
    SizeC1minusVap=-Inf,
    ftsw=-Inf,
    rain_remain=-Inf,
    rain_effective=-Inf,
    runoff=-Inf,
    soil_depth=-Inf,
    transpiration=-Inf,
)

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
function compute_compartment_size(m, status)
    Taille_WP = m.H_WP_Z1 * m.Z1
    # Size of the evaporative component of the first layer:
    status.SizeVap = 0.5 * Taille_WP
    # NB: the 0.5 is because water can still evaporate below the wilting point
    # in the first layer, considered at 0.5 * H_WP. 
    #! replace 0.5 * m.H_WP by a parameter

    # Size of the evapotranspirable water layer in the first soil layer:
    if status.root_depth > m.Z1
        status.SizeC1 = m.H_FC * m.Z1 - (Taille_WP - status.SizeVap)
        # m.H_FC * m.Z1 -> size of the first layer at field capacity
        # (Taille_WP - SizeVap) -> size of the first layer that will never evapotranspirate
        # SizeC1 -> size of the first layer that can evapotranspirate
    else
        status.SizeC1 = max(0.0, m.H_FC * status.root_depth - status.SizeVap)
    end

    status.SizeC1minusVap = max(0.0, status.SizeC1 - status.SizeVap)

    if (status.root_depth > m.Z2 + m.Z1)
        status.SizeC2 = (m.H_FC - m.H_WP_Z2) * m.Z2
    else
        status.SizeC2 = max(0.0, (m.H_FC - m.H_WP_Z2) * (status.root_depth - m.Z1))
    end

    status.SizeC = status.SizeC2 + status.SizeC1minusVap
end

function compute_fraction!(status)
    status.FractionC1 = status.qty_H2O_C1 / status.SizeC1
    if status.SizeC2 > 0.0
        status.FractionC2 = status.qty_H2O_C2 / status.SizeC2
    else
        status.FractionC2 = 0.0
    end

    if status.SizeC > 0.0
        status.ftsw = status.qty_H2O_C / status.SizeC
    else
        status.ftsw = 0.0
    end
end

function soil_init_default(m)
    @assert m.H_0 <= m.H_FC "H_0 cannot be higher than H_FC"

    # init status
    status = PlantSimEngine.Status(
        root_depth=-Inf, ini_root_depth=-Inf, aPPFD=-Inf, ET0=-Inf, qty_H2O_Vap=-Inf,
        qty_H2O_C1=-Inf, qty_H2O_C1minusVap=-Inf, qty_H2O_C2=-Inf, qty_H2O_C=-Inf, FractionC1=-Inf,
        FractionC2=-Inf, SizeC1=-Inf, SizeC2=-Inf, SizeC=-Inf, SizeVap=-Inf, SizeC1minusVap=-Inf,
        ftsw=-Inf, rain_remain=-Inf, rain_effective=-Inf, runoff=-Inf, soil_depth=-Inf
    )
    ## init compartments size
    status.root_depth = m.ini_root_depth
    compute_compartment_size(m, status)

    a_vap = min(status.SizeVap, (m.H_0 - m.H_WP_Z1) * m.Z1)
    status.qty_H2O_Vap = max(0.0, a_vap)

    a_C1 = min(status.SizeC1, (m.H_0 - m.H_WP_Z1) * m.Z1)
    status.qty_H2O_C1 = max(0.0, a_C1)

    a_C1moinsV = status.qty_H2O_C1 - status.qty_H2O_Vap
    status.qty_H2O_C1minusVap = max(0.0, a_C1moinsV)

    a_C2 = min(status.SizeC2, (m.H_0 - m.H_WP_Z2) * m.Z2)
    status.qty_H2O_C2 = max(0.0, a_C2)

    a_C = status.qty_H2O_C1 + status.qty_H2O_C2 - status.qty_H2O_Vap
    status.qty_H2O_C = max(0.0, a_C)

    compute_fraction!(status)
    return status
end

function PlantSimEngine.run!(m::T, models, st, meteo, constants, extra=nothing) where {T<:FTSW}
    rain = meteo.Precipitations
    st.root_depth = prev_value(st, :root_depth; default=m.ini_root_depth)

    # Initialize the water content to the values from the previous time step
    st.qty_H2O_C1minusVap = prev_value(st, :qty_H2O_C1minusVap; default=m.ini_qty_H2O_C1minusVap)
    st.qty_H2O_C2 = prev_value(st, :qty_H2O_C2; default=m.ini_qty_H2O_C2)
    st.qty_H2O_C = prev_value(st, :qty_H2O_C; default=m.ini_qty_H2O_C)
    st.qty_H2O_C1 = prev_value(st, :qty_H2O_C1; default=m.ini_qty_H2O_C1)
    st.qty_H2O_Vap = prev_value(st, :qty_H2O_Vap; default=m.ini_qty_H2O_Vap)
    # Note: if we are computing the first time step, the previous values are the values already in the variables (=initial values)

    compute_compartment_size(m, st)

    transmitted_light_fraction = (meteo.Ri_PAR_f * constants.J_to_umol - st.aPPFD) / (meteo.Ri_PAR_f * constants.J_to_umol)

    EvapMax = transmitted_light_fraction * st.ET0 * m.KC
    Transp_Max = (1.0 - transmitted_light_fraction) * st.ET0 * m.KC

    # estim effective rain (runoff)
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

    st.rain_effective = rain_soil + stemflow

    st.runoff = rain - st.rain_effective

    # balance after rain

    if (st.qty_H2O_Vap + st.rain_effective) >= st.SizeVap
        st.rain_remain = st.rain_effective + st.qty_H2O_Vap - st.SizeVap
        st.qty_H2O_Vap = st.SizeVap # evaporative compartment is full
        if (st.qty_H2O_C1minusVap + st.rain_remain) >= st.SizeC1minusVap
            st.rain_remain = st.rain_remain + st.qty_H2O_C1minusVap - st.SizeC1minusVap
            st.qty_H2O_C1minusVap = st.SizeC1minusVap # Transpirative compartment in the first layer is full

            if (st.qty_H2O_C2 + st.rain_remain) >= st.SizeC2
                st.rain_remain = st.rain_remain + st.qty_H2O_C2 - st.SizeC2
                st.qty_H2O_C2 = st.SizeC2 # Transpirative compartment in the second layer is full
            else
                st.qty_H2O_C2 += st.rain_remain
                st.rain_remain = 0.0
            end
        else
            st.qty_H2O_C1minusVap += st.rain_remain
            st.rain_remain = 0.0
        end

    else
        st.qty_H2O_Vap += st.rain_effective
        st.rain_remain = 0.0
    end
    st.qty_H2O_C1 = st.qty_H2O_C1minusVap + st.qty_H2O_Vap
    st.qty_H2O_C = st.qty_H2O_C1minusVap + st.qty_H2O_C2

    compute_fraction!(st)

    # balance after evaporation
    Evap = EvapMax * KS(st.FractionC1, m.TRESH_EVAP)

    if st.qty_H2O_C1minusVap - Evap >= 0.0 # first evaporation on the evapotranspirative compartment
        st.qty_H2O_C1minusVap += -Evap
        EvapC1minusVap = Evap
        EvapVap = 0.0
    else
        EvapC1minusVap = st.qty_H2O_C1minusVap # then evaporation only on the evaporative compartment
        st.qty_H2O_C1minusVap = 0.0
        EvapVap = Evap - EvapC1minusVap
        if st.qty_H2O_Vap - EvapVap >= 0.0 #  evaporation on the evaporative compartment
            st.qty_H2O_Vap += -EvapVap
            EvapVap = 0.0
        else
            EvapVap = EvapVap - st.qty_H2O_Vap
            st.qty_H2O_Vap = 0.0
        end

    end
    st.qty_H2O_C1 = st.qty_H2O_C1minusVap + st.qty_H2O_Vap
    st.qty_H2O_C = st.qty_H2O_C1 + st.qty_H2O_C2 - st.qty_H2O_Vap

    compute_fraction!(st)

    # balance after transpiration
    st.transpiration = Transp_Max * KS(m.TRESH_FTSW_TRANSPI, st.ftsw)
    # st.transpiration = 0.0
    if st.qty_H2O_C2 > 0.0
        TranspiC2 = min(st.transpiration * (st.qty_H2O_C2 / (st.qty_H2O_C2 + st.qty_H2O_C1minusVap)), st.qty_H2O_C2)
    else
        TranspiC2 = 0
    end

    if st.qty_H2O_C1minusVap > 0
        TranspiC1minusVap = min(st.transpiration * (st.qty_H2O_C1minusVap / (st.qty_H2O_C2 + st.qty_H2O_C1minusVap)), st.qty_H2O_C1minusVap)
    else
        TranspiC1minusVap = 0
    end

    st.qty_H2O_C1minusVap -= TranspiC1minusVap
    st.qty_H2O_C2 -= TranspiC2
    st.qty_H2O_C = st.qty_H2O_C2 + st.qty_H2O_C1minusVap
    st.qty_H2O_C1 = st.qty_H2O_Vap + st.qty_H2O_C1minusVap

    st.soil_depth = m.Z1 + m.Z2

    compute_fraction!(st)
end

# Method to get the FTSW value from other organs:
function PlantSimEngine.run!(::FTSW, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    scene = MultiScaleTreeGraph.get_root(mtg)
    timestep = rownumber(st)
    MultiScaleTreeGraph.traverse(scene, symbol="Soil") do soil
        st.ftsw = soil[:models].status[timestep].ftsw
    end
    nothing
end

PlantSimEngine.inputs_(::FTSW{T}) where {T<:Organ} = NamedTuple()
PlantSimEngine.outputs_(::FTSW{T}) where {T<:Organ} = (
    ftsw=-Inf,
)

# Method to run the FTSW model from the root system:
function PlantSimEngine.run!(::FTSW{RootSystem}, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    scene = MultiScaleTreeGraph.get_root(mtg)
    timestep = rownumber(st)
    MultiScaleTreeGraph.traverse(scene, symbol="Soil") do soil
        soil_st = soil[:models].status[timestep]
        st.ftsw = soil_st.ftsw
        st.soil_depth = soil_st.soil_depth
    end
    nothing
end

PlantSimEngine.outputs_(::FTSW{RootSystem}) = (
    ftsw=-Inf,
    soil_depth=-Inf,
)