"""
    FTSW_BP(H_FC::Float64, H_WP_Z1::Float64,Z1::Float64,H_WP_Z2::Float64,Z2::Float64,H_0::Float64,KC::Float64,TRESH_EVAP::Float64,TRESH_FTSW_TRANSPI::Float64)

Fraction of Transpirable Soil Water model.

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
struct FTSW_BP <: AbstractFTSWModel
    ini_root_depth::Float64   # root depth at initialization (mm)
    H_FC::Float64
    H_WP_Z1::Float64
    Z1::Float64
    H_WP_Z2::Float64
    Z2::Float64
    H_0::Float64
    KC::Float64
    TRESH_EVAP::Float64
    TRESH_FTSW_TRANSPI::Float64
    ini_qty_H2O_Vap::Float64  # quantity of water in evaporative compartment
    ini_qty_H2O_C1::Float64   # quantity of water in C1 compartment
    ini_qty_H2O_C1minusVap::Float64
    ini_qty_H2O_C2::Float64   # quantity of water in C2 compartment
    ini_qty_H2O_C::Float64    # quantity of water in C compartment
    ini_qty_H2O_Vap_Roots::Float64
    ini_qty_H2O_C1_Roots::Float64
    ini_qty_H2O_C1minusVap_Roots::Float64
    ini_qty_H2O_C2_Roots::Float64
    ini_qty_H2O_C_Roots::Float64
end

PlantSimEngine.inputs_(::FTSW_BP) = (
    root_depth=-Inf,
    ET0=-Inf, #potential evapotranspiration
    tree_ei=-Inf, # light interception efficiency (ei=1-exp(-kLAI))
)

function FTSW_BP(;
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
    FTSW_BP(ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI)
end

function FTSW_BP(ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI)
    soil = FTSW_BP(ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    init = soil_init_default(soil)
    FTSW_BP(
        ini_root_depth, H_FC, H_WP_Z1, Z1, H_WP_Z2, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI,
        init.qty_H2O_Vap, init.qty_H2O_C1, init.qty_H2O_C1minusVap, init.qty_H2O_C2, init.qty_H2O_C, init.qty_H2O_Vap_Roots, init.qty_H2O_C1_Roots, init.qty_H2O_C1minusVap_Roots, init.qty_H2O_C2_Roots, init.qty_H2O_C_Roots
    )
end

PlantSimEngine.outputs_(::FTSW_BP) = (
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

    # Size of the evapotranspirable water layer in the first soil layer:
    # NB: the 0.5 is because water can still evaporate below the wilting point
    if status.root_depth > m.Z1
        status.SizeC1 = (H_FC - 0.5 * m.H_WP_Z1) * Z1
        status.SizeVap = 0.5 * m.H_WP_Z1 * Z1
    else
        status.SizeC1 = (H_FC - 0.5 * m.H_WP_Z1) * status.root_depth
        status.SizeVap = 0.5 * m.H_WP_Z1 * status.root_depth
    end

    status.SizeC1minusVap = status.SizeC1 - status.SizeVap

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
    status.FractionC = status.qty_H2O_C / status.SizeC
    status.FractionC1Roots = status.qty_H2O_C1_Racines / status.roots_SizeC1
    if (roots_SizeC2 > 0)
        status.FractionC2Roots = status.qty_H2O_C2_roots / status.roots_SizeC2
    else
        status.FractionC2Roots = 0
    end
    status.ftsw = status.qty_H2O_C_Roots / status.roots_SizeC
    status.FractionC1minusVapRoots = status.qty_H2O_C1minusVap_Roots / status.roots_SizeC1minusVap

end

function soil_init_default(m)
    @assert m.H_0 <= m.H_FC "H_0 cannot be higher than H_FC"

    # init status
    status = PlantSimEngine.Status(merge(PlantSimEngine.inputs_(m), PlantSimEngine.outputs_(m)))
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


    status.qty_H2O_C1_Roots = max(0.0, status.qty_H2O_C1 * status.roots_SizeC1 / status.SizeC1)
    status.qty_H2O_Vap_Roots = max(0.0, status.qty_H2O_Vap * status.roots_SizeVap / TailleVap)
    status.qty_H2O_C2_Roots = max(0.0, status.qty_H2O_C2 * status.roots_SizeC2 / status.SizeC2)
    status.qty_H2O_C_Roots = max(0.0, status.qty_H2O_C * status.roots_SizeC / status.SizeC)
    status.qty_H2O_C1minusVap_Roots = max(0.0, status.qty_H2O_C1minusVap * status.roots_SizeC1moinsVap / status.SizeC1minusVap)

    compute_fraction!(status)
    return status
end

function PlantSimEngine.run!(m::FTSW, models, st, meteo, constants, extra=nothing)
    rain = meteo.Precipitations

    # Initialize the water content to the values from the previous time step
    st.qty_H2O_C1minusVap = PlantMeteo.prev_value(st, :qty_H2O_C1minusVap; default=m.ini_qty_H2O_C1minusVap)
    st.qty_H2O_C2 = PlantMeteo.prev_value(st, :qty_H2O_C2; default=m.ini_qty_H2O_C2)
    st.qty_H2O_C = PlantMeteo.prev_value(st, :qty_H2O_C; default=m.ini_qty_H2O_C)
    st.qty_H2O_C1 = PlantMeteo.prev_value(st, :qty_H2O_C1; default=m.ini_qty_H2O_C1)
    st.qty_H2O_Vap = PlantMeteo.prev_value(st, :qty_H2O_Vap; default=m.ini_qty_H2O_Vap)

    status.qty_H2O_C1_Roots = PlantMeteo.prev_value(st, :qty_H2O_C1_Roots; default=m.ini_qty_H2O_C1_Roots)
    status.qty_H2O_Vap_Roots = PlantMeteo.prev_value(st, :qty_H2O_Vap_Roots; default=m.ini_qty_H2O_Vap_Roots)
    status.qty_H2O_C2_Roots = PlantMeteo.prev_value(st, :qty_H2O_C2_Roots; default=m.ini_qty_H2O_C2_Roots)
    status.qty_H2O_C_Roots = PlantMeteo.prev_value(st, :qty_H2O_C_Roots; default=m.ini_qty_H2O_C_Roots)

    # Note: if we are computing the first time step, the previous values are the values already in the variables (=initial values)

    compute_compartment_size(m, st)

    EvapMax = (1 - st.tree_ei) * st.ET0 * m.KC
    Transp_Max = st.tree_ei * st.ET0 * m.KC

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

    # compute water balance after rain
    mem_qte_H2O_C1 = status.qty_H2O_C1
    mem_qte_H2O_Vap = status.qty_H2O_Vap
    if ((status.qty_H2O_Vap + pluie_efficace) >= TailleVap)
        status.qty_H2O_Vap = TailleVap
        if ((status.qty_H2O_C1minusVap + (pluie_efficace - TailleVap + mem_qte_H2O_Vap)) >= status.SizeC1minusVap)
            status.qty_H2O_C1minusVap = status.SizeC1minusVap
            status.qty_H2O_C1 = status.qty_H2O_C1minusVap + status.qty_H2O_Vap
            if ((status.qty_H2O_C2 + mem_qte_H2O_C1 + pluie_efficace - status.SizeC1) >= status.SizeC2)
                status.qty_H2O_C2 = status.SizeC2
            else
                status.qty_H2O_C2 += mem_qte_H2O_C1 + pluie_efficace - status.SizeC1
            end
        else
            status.qty_H2O_C1minusVap += pluie_efficace - TailleVap + mem_qte_H2O_Vap
            status.qty_H2O_C1 = status.qty_H2O_C1minusVap + status.qty_H2O_Vap
        end
    else
        status.qty_H2O_Vap += pluie_efficace
        status.qty_H2O_C1 = status.qty_H2O_Vap + status.qty_H2O_C1minusVap
    end
    status.qty_H2O_C = status.qty_H2O_C1minusVap + status.qty_H2O_C2

    #    compute roots water balance after rain
    mem_qty_H2O_C1_Roots = status.qty_H2O_C1_Roots
    mem_qte_H2O_Vap_Racines = status.qty_H2O_Vap_Roots
    if ((status.qty_H2O_Vap_Roots + pluie_efficace) >= status.roots_SizeVap)
        status.qty_H2O_Vap_Roots = status.roots_SizeVap
        if ((status.qty_H2O_C1minusVap_Roots + (pluie_efficace - status.roots_SizeVap + mem_qte_H2O_Vap_Racines)) >= status.roots_SizeC1minusVap)
            status.qty_H2O_C1minusVap_Roots = status.roots_SizeC1minusVap
            status.qty_H2O_C1_Roots = status.qty_H2O_C1minusVap_Roots + status.qty_H2O_Vap_Roots
            if ((status.qty_H2O_C2_Roots + mem_qty_H2O_C1_Roots + pluie_efficace - status.roots_SizeC1) >= status.roots_SizeC2)
                status.qty_H2O_C2_Roots = status.roots_SizeC2
            else
                status.qty_H2O_C2_Roots += mem_qty_H2O_C1_Roots + pluie_efficace - status.roots_SizeC1
            end
        else
            status.qty_H2O_C1minusVap_Roots += pluie_efficace - status.roots_SizeVap + mem_qte_H2O_Vap_Racines
            status.qty_H2O_C1_Roots = status.qty_H2O_C1minusVap_Roots + status.qty_H2O_Vap_Roots
        end
    else
        status.qty_H2O_Vap_Roots += pluie_efficace
        status.qty_H2O_C1_Roots = status.qty_H2O_C1minusVap_Roots + status.qty_H2O_Vap_Roots
    end
    status.qty_H2O_C_Roots = status.qty_H2O_C1minusVap_Roots + status.qty_H2O_C2_Roots

    compute_fraction!()

    #  compute water bamance after rain
    Evap = EvapMax * KS(st.FractionC1, m.TRESH_EVAP)
    if (status.qty_H2O_C1minusVap - Evap >= 0)
        status.qty_H2O_C1minusVap += -Evap
        EvapC1minusVap = Evap
        EvapVap = 0
    else
        EvapC1minusVap = status.qty_H2O_C1minusVap
        status.qty_H2O_C1minusVap = 0
        EvapVap = Evap - EvapC1minusVap
        status.qty_H2O_Vap += -EvapVap
    end
    status.qty_H2O_C1 = status.qty_H2O_C1minusVap + status.qty_H2O_Vap
    status.qty_H2O_C = status.qty_H2O_C1 + status.qty_H2O_C2 - status.qty_H2O_Vap

    #  compute water balance roots after evaporation
    a_C1minusVap_Roots = status.qty_H2O_C1minusVap_Roots - EvapC1minusVap * status.roots_SizeC1minusVap / status.SizeC1minusVap
    status.qty_H2O_C1minusVap_Roots = max(0.0, a_C1minusVap_Roots)
    a_Vap_Roots = status.qty_H2O_Vap_Roots - EvapVap * status.roots_SizeVap / TailleVap
    status.qty_H2O_Vap_Roots = max(0.0, a_Vap_Roots)
    status.qty_H2O_C1_Roots = status.qty_H2O_Vap_Roots + status.qty_H2O_C1minusVap_Roots
    status.qty_H2O_C_Roots = status.qty_H2O_C2_Roots + status.qty_H2O_C1minusVap_Roots

    compute_fraction!()

    # compute water balance  roots after Transpiration

    Transpi = Transp_Max * KS(m.TRESH_FTSW_TRANSPI, st.ftsw)
    if (status.qty_H2O_C2_Roots > 0)
        TranspiC2 = min(Transpi * (status.qty_H2O_C2_Roots / (status.qty_H2O_C2_Roots + status.qty_H2O_C1minusVap_Roots)), status.qty_H2O_C2_Roots)
    else
        TranspiC2 = 0
    end
    if (status.qty_H2O_C1minusVap_Roots > 0)
        TranspiC1moinsVap = min(Transpi * (status.qty_H2O_C1minusVap_Roots / (status.qty_H2O_C2_Roots + status.qty_H2O_C1minusVap_Roots)), status.qty_H2O_C1minusVap_Roots)
    else
        TranspiC1moinsVap = 0
    end
    status.qty_H2O_C1minusVap_Roots += -TranspiC1moinsVap
    status.qty_H2O_C2_Roots += -TranspiC2
    status.qty_H2O_C_Roots = status.qty_H2O_C2_Roots + status.qty_H2O_C1minusVap_Roots
    status.qty_H2O_C1_Roots = status.qty_H2O_Vap_Roots + status.qty_H2O_C1minusVap_Roots


    # compute water balance after transpiration
    status.qty_H2O_C1minusVap += -TranspiC1moinsVap
    status.qty_H2O_C2 += -TranspiC2
    status.qty_H2O_C = status.qty_H2O_C2 + status.qty_H2O_C1minusVap
    status.qty_H2O_C1 = status.qty_H2O_Vap + status.qty_H2O_C1minusVap

    compute_fraction!()
end
