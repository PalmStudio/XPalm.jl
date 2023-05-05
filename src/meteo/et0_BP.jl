@process "potential_evapotranspiration" verbose = false

"""
    ET0(TRESH_FTSW_SLOW_ROOTS, ROOTS_GROWTH_DEPTH, Z1, Z2)
    ET0(TRESH_FTSW_SLOW_ROOTS=0.2, ROOTS_GROWTH_DEPTH=0.3, Z1=200, Z2=2000)

Compute root growth depending on thermal time and water stress (ftsw)

# Arguments

- `ROOTS_GROWTH_DEPTH`: root growth in depth (mm.degreeC days-1)
- `TRESH_FTSW_SLOW_ROOTS`: ftsw treshold below which roots growth is reduced (unitless [0:1])
- `Z1`: Thickness of the first soil layer (mm)
- `Z2`: Thickness of the second soil layer (mm)
"""
struct RootGrowth{T} <: AbstractPotential_EvapotranspirationModel
    ROOTS_GROWTH_DEPTH::T
    TRESH_FTSW_SLOW_ROOTS::T
    Z1::T
    Z2::T
end


PlantSimEngine.inputs_(::RootGrowth) = (
    ftsw=-Inf, # fraction of transpirable soil water (unitless [0:1])
    TEff=-Inf, # daily efficient temperature for plant growth (degree C days) 
)

PlantSimEngine.outputs_(::RootGrowth) = (
    root_depth=-Inf, # root depth (cm)
)


function RootGrowth(;
    ROOTS_GROWTH_DEPTH=25,
    TRESH_FTSW_SLOW_ROOTS=30,
    Z1=15,
    Z2=40
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

    Date=meteo.ObservationDate
    tDay =datetime2julian.(DateTime.(Date))

    double TMoy = (Tmax + Tmin) / 2;
    double HMoy = (RHmin + RHmax) / 2;

    if (Tmin > Tmax)
        Tmax = Tmin;
    if (RHmin > RHmax)
        RHmax = RHmin;

    double Decli = 0.409 * sin(0.0172 * tDay - 1.39);
    double SunPos = acos(-tan(lat_rad) * tan(Decli));
    double Sundist = 1 + 0.033 * cos(2 * (_PI / 365) * tDay);
    double Ray_extra = 24 * 60 * 0.0820 / _PI * Sundist * (SunPos * sin(Decli) * sin(lat_rad) + cos(Decli) * cos(lat_rad) * sin(SunPos));
    double RGMax = (0.75 + 0.00002 * ALTITUDE) * Ray_extra;
    double day_length = 7.64 * SunPos;
    double PAR = 0.48 * Rg;
    double esat = 0.3054 * (exp(17.24 * Tmax / (Tmax + 237.3)) + exp(17.27 * Tmin / (Tmin + 237.3)));
    double ea = 0.3054 * (exp(17.27 * Tmax / (Tmax + 237.3)) * RHmin / 100 + exp(17.27 * Tmin / (Tmin + 237.3)) * RHmax / 100);
    double VPD = esat - ea;
    double ratioRg = (Rg > RGMax) ? 1 : Rg / RGMax;
    double Rn = 0.77 * Rg - (1.35 * ratioRg - 0.35) *
                                (0.34 - 0.14 * std::pow(ea, 0.5)) *
                                (pow(Tmax + 273.16, 4) + std::pow(Tmin + 273.16, 4)) * 2.45015 * std::pow(10, -9);
    double Tlat = 2.501 - 2.361 * std::pow(10, -3) * TMoy;
    double pent_vap_sat = 4098 * (0.6108 * exp(17.27 * TMoy / (TMoy + 237.3))) / pow((TMoy + 237.3), 2);
    double Kpsy = 0.00163 * 101.3 * pow((1 - (0.0065 * ALTITUDE / 293)), 5.26); // TODO BUG
    // should be
    //             KPsy = 0.00163 * 101.3 * std::pow(1 - (0.0065 * Altitude * 1.0 / 293), 5.26) / TLat;

    double erad = 0.408 * Rn * pent_vap_sat / (pent_vap_sat + Kpsy * (1 + 0.34 * windspeed));
    double eaero = ((900 / (TMoy + 273.16)) * ((esat - ea) * windspeed) * Kpsy) / (pent_vap_sat + Kpsy * (1 + 0.34 * windspeed));
    Et0 = erad + eaero;
end
