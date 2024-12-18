struct FTSW_CPP{T} <: AbstractFTSWModel
    # Parameters
    H_FC::T
    H_WP_Z1::T
    Z1::T
    H_WP::T
    Z2::T
    H_0::T
    KC::T
    TRESH_EVAP::T
    TRESH_FTSW_TRANSPI::T

    # State variables
    root_depth::T  # Root depth (mm)
    TailleC::T    # Size of compartment C
    TailleC1::T   # Size of compartment C1
    TailleC2::T   # Size of compartment C2
    TailleVap::T  # Size of evaporative compartment
    TailleC1moinsVap::T # Size of C1 minus evaporative compartment

    # Water quantities
    qte_H2O_C::T
    qte_H2O_C1::T
    qte_H2O_C2::T
    qte_H2O_Vap::T
    qte_H2O_C1moinsVap::T

    # Root water quantities
    qte_H2O_C_Racines::T
    qte_H2O_C1_Racines::T
    qte_H2O_C2_Racines::T
    qte_H2O_Vap_Racines::T
    qte_H2O_C1moinsVap_Racines::T

    # Fractions
    FractionC::T
    FractionC1::T
    FractionC2::T
    FractionC1Racine::T
    FractionC2Racine::T
    FractionC1moinsVapRacine::T
    ftsw::T
end

function FTSW_CPP(;
    ini_root_depth,
    H_FC=0.23,
    H_WP_Z1=0.05,
    Z1=200.0,
    H_WP=0.05,
    Z2=2000.0,
    H_0=0.15,
    KC=1.0,
    TRESH_EVAP=0.5,
    TRESH_FTSW_TRANSPI=0.5
)
    vals = promote(
        H_FC, H_WP_Z1, Z1, H_WP, Z2, H_0, KC, TRESH_EVAP, TRESH_FTSW_TRANSPI,
        ini_root_depth, 0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5
    )
    FTSW_CPP(vals...)
end

PlantSimEngine.inputs_(::FTSW_CPP) = (
    ET0=-Inf,      # Potential evapotranspiration
    rain=-Inf,     # Rainfall
    tree_ei=-Inf,  # Tree interception efficiency
    root_depth=-Inf # Root depth
)

PlantSimEngine.outputs_(m::FTSW_CPP) = (
    ftsw=m.ftsw,
    qte_H2O_C=m.qte_H2O_C,
    qte_H2O_C1=m.qte_H2O_C1,
    qte_H2O_C2=m.qte_H2O_C2,
    qte_H2O_Vap=m.qte_H2O_Vap,
    qte_H2O_C1moinsVap=m.qte_H2O_C1moinsVap
)

function compute_root_quantities!(st)
    # Update root water quantities based on root proportions
    st.qte_H2O_C1_Racines = max(0.0, st.qte_H2O_C1 * st.racines_TailleC1 / st.TailleC1)
    st.qte_H2O_Vap_Racines = max(0.0, st.qte_H2O_Vap * st.racines_TailleVap / st.TailleVap)
    st.qte_H2O_C2_Racines = max(0.0, st.qte_H2O_C2 * st.racines_TailleC2 / st.TailleC2)
    st.qte_H2O_C_Racines = max(0.0, st.qte_H2O_C * st.racines_TailleC / st.TailleC)
    st.qte_H2O_C1moinsVap_Racines = max(0.0, st.qte_H2O_C1moinsVap * st.racines_TailleC1moinsVap / st.TailleC1moinsVap)
end

function compute_fractions!(st)
    # Calculate fractions for each compartment
    st.FractionC1 = st.qte_H2O_C1 / st.TailleC1
    st.FractionC2 = st.TailleC2 > 0 ? st.qte_H2O_C2 / st.TailleC2 : 0.0
    st.FractionC = st.qte_H2O_C / st.TailleC
    st.FractionC1Racine = st.qte_H2O_C1_Racines / st.racines_TailleC1
    st.FractionC2Racine = st.racines_TailleC2 > 0 ? st.qte_H2O_C2_Racines / st.racines_TailleC2 : 0.0
    st.ftsw = st.qte_H2O_C_Racines / st.racines_TailleC
    st.FractionC1moinsVapRacine = st.qte_H2O_C1moinsVap_Racines / st.racines_TailleC1moinsVap
end

function compute_evapotranspiration!(st, inputs)
    # Calculate potential evaporation and transpiration
    st.EvapMax = (1 - inputs.tree_ei) * inputs.ET0 * st.KC
    st.Transp_Max = inputs.tree_ei * inputs.ET0 * st.KC

    # Calculate actual evaporation
    st.Evap = st.EvapMax * (st.FractionC1 > st.TRESH_EVAP ? 1.0 : st.FractionC1 / st.TRESH_EVAP)

    # Process evaporation from different compartments
    if st.qte_H2O_C1moinsVap - st.Evap >= 0
        st.qte_H2O_C1moinsVap -= st.Evap
        st.EvapC1moinsVap = st.Evap
        st.EvapVap = 0.0
    else
        st.EvapC1moinsVap = st.qte_H2O_C1moinsVap
        st.qte_H2O_C1moinsVap = 0.0
        st.EvapVap = st.Evap - st.EvapC1moinsVap
        st.qte_H2O_Vap -= st.EvapVap
    end

    # Calculate transpiration
    st.Transpi = st.Transp_Max * (st.ftsw > st.TRESH_FTSW_TRANSPI ? 1.0 : st.ftsw / st.TRESH_FTSW_TRANSPI)

    # Distribute transpiration between compartments
    if st.qte_H2O_C2_Racines > 0
        st.TranspiC2 = min(st.Transpi * (st.qte_H2O_C2_Racines / (st.qte_H2O_C2_Racines + st.qte_H2O_C1moinsVap_Racines)), st.qte_H2O_C2_Racines)
    else
        st.TranspiC2 = 0.0
    end

    if st.qte_H2O_C1moinsVap_Racines > 0
        st.TranspiC1moinsVap = min(st.Transpi * (st.qte_H2O_C1moinsVap_Racines / (st.qte_H2O_C2_Racines + st.qte_H2O_C1moinsVap_Racines)), st.qte_H2O_C1moinsVap_Racines)
    else
        st.TranspiC1moinsVap = 0.0
    end
end

function compute_rainfall!(st, inputs)
    # Calculate effective rainfall
    pluie_au_sol = max(0.0, 0.916 * inputs.rain - 0.589)
    ecoul_stipe = max(0.0, 0.0713 * inputs.rain - 0.735)
    st.pluie_efficace = pluie_au_sol + ecoul_stipe

    # Store current state for calculations
    mem_qte_H2O_C1 = st.qte_H2O_C1
    mem_qte_H2O_Vap = st.qte_H2O_Vap

    # Update water quantities after rainfall
    if (st.qte_H2O_Vap + st.pluie_efficace) >= st.TailleVap
        st.qte_H2O_Vap = st.TailleVap
        if (st.qte_H2O_C1moinsVap + (st.pluie_efficace - st.TailleVap + mem_qte_H2O_Vap)) >= st.TailleC1moinsVap
            st.qte_H2O_C1moinsVap = st.TailleC1moinsVap
            st.qte_H2O_C1 = st.qte_H2O_C1moinsVap + st.qte_H2O_Vap
            if (st.qte_H2O_C2 + mem_qte_H2O_C1 + st.pluie_efficace - st.TailleC1) >= st.TailleC2
                st.qte_H2O_C2 = st.TailleC2
            else
                st.qte_H2O_C2 += mem_qte_H2O_C1 + st.pluie_efficace - st.TailleC1
            end
        else
            st.qte_H2O_C1moinsVap += st.pluie_efficace - st.TailleVap + mem_qte_H2O_Vap
            st.qte_H2O_C1 = st.qte_H2O_C1moinsVap + st.qte_H2O_Vap
        end
    else
        st.qte_H2O_Vap += st.pluie_efficace
        st.qte_H2O_C1 = st.qte_H2O_Vap + st.qte_H2O_C1moinsVap
    end
end

function update_water_balance!(st)
    # Update water content after transpiration
    st.qte_H2O_C1moinsVap -= st.TranspiC1moinsVap
    st.qte_H2O_C2 -= st.TranspiC2

    # Update total water contents
    st.qte_H2O_C = st.qte_H2O_C2 + st.qte_H2O_C1moinsVap
    st.qte_H2O_C1 = st.qte_H2O_Vap + st.qte_H2O_C1moinsVap

    # Update root water contents
    st.qte_H2O_C1moinsVap_Racines -= st.TranspiC1moinsVap
    st.qte_H2O_C2_Racines -= st.TranspiC2
    st.qte_H2O_C_Racines = st.qte_H2O_C2_Racines + st.qte_H2O_C1moinsVap_Racines
    st.qte_H2O_C1_Racines = st.qte_H2O_Vap_Racines + st.qte_H2O_C1moinsVap_Racines
end

function initialize!(m::FTSW_CPP, st)
    # Initialize sizes
    st.TailleC1 = (m.H_FC - m.H_WP_Z1) * m.Z1
    st.TailleVap = m.H_WP_Z1 * m.Z1
    st.TailleC1moinsVap = st.TailleC1 - st.TailleVap
    st.TailleC2 = (m.H_FC - m.H_WP) * m.Z2
    st.TailleC = st.TailleC2 + st.TailleC1 - st.TailleVap

    # Initialize water quantities
    st.qte_H2O_C1 = max(0.0, min(st.TailleC1, (m.H_0 - m.H_WP_Z1) * m.Z1))
    st.qte_H2O_Vap = max(0.0, min(st.TailleVap, (m.H_0 - m.H_WP_Z1) * m.Z1))
    st.qte_H2O_C2 = max(0.0, min(st.TailleC2, (m.H_0 - m.H_WP) * m.Z2))
    st.qte_H2O_C1moinsVap = max(0.0, st.qte_H2O_C1 - st.qte_H2O_Vap)
    st.qte_H2O_C = max(0.0, st.qte_H2O_C1 + st.qte_H2O_C2 - st.qte_H2O_Vap)

    compute_root_quantities!(st)
    compute_fractions!(st)
end

function PlantSimEngine.run!(m::FTSW_CPP, st, inputs)
    compute_evapotranspiration!(st, inputs)
    compute_rainfall!(st, inputs)
    update_water_balance!(st)
    compute_root_quantities!(st)
    compute_fractions!(st)
end