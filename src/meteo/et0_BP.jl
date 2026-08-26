
"""
    ET0_BP(LATITUDE,ALTITUDE)
    ET0_BP(LATITUDE=0.97,ALTITUDE=50)

Compute potential evapotranspiration 

# Arguments

- `LATITUDE`: latitude (radian)
- `ALTITUDE`: altitude (m)

# Environment inputs

- `Tmin`, `Tmax`: daily minimum and maximum air temperatures.
- `Rh_min`, `Rh_max`: daily minimum and maximum relative humidities.
- `Rg`: daily global radiation.
- `Wind`: wind speed.
- `date`: date of the meteorological record.

# Outputs

- `ET0`: potential evapotranpiration (mm)
"""
struct ET0_BP{T} <: AbstractPotential_EvapotranspirationModel
    LATITUDE::T
    ALTITUDE::T
end


PlantSimEngine.inputs_(::ET0_BP) = NamedTuple()

PlantSimEngine.environment_inputs_(::ET0_BP) = (
    Tmin=0.0,
    Tmax=0.0,
    Rh_min=0.0,
    Rh_max=0.0,
    Rg=0.0,
    Wind=0.0,
    date=Dates.Date(2000, 1, 1),
)

PlantSimEngine.outputs_(::ET0_BP) = (
    ET0=-Inf, # potential evpotranspiration (mm)
)

function ET0_BP(;
    LATITUDE=0.97,
    ALTITUDE=50.0
)
    ET0_BP(LATITUDE, ALTITUDE)
end


function PlantSimEngine.run!(m::ET0_BP, status, environment, constants, context=nothing)

    Tmin = environment.Tmin
    Tmax = environment.Tmax
    RHmin = environment.Rh_min #check plantMeteo variable names
    RHmax = environment.Rh_max #check plantMeteo variable names
    Rg = environment.Rg
    windspeed = environment.Wind

    tDay = Dates.datetime2julian(Dates.DateTime(environment.date))

    TMoy = (Tmax + Tmin) / 2

    Tmax = ifelse(Tmin > Tmax, Tmin, Tmax)
    RHmax = ifelse(RHmin > RHmax, RHmin, RHmax)


    Decli = 0.409 * sin(0.0172 * tDay - 1.39)
    SunPos = acos(-tan(m.LATITUDE) * tan(Decli))
    Sundist = 1 + 0.033 * cos(2 * (pi / 365) * tDay)
    Ray_extra = 24 * 60 * 0.0820 / pi * Sundist * (SunPos * sin(Decli) * sin(m.LATITUDE) + cos(Decli) * cos(m.LATITUDE) * sin(SunPos))
    RGMax = (0.75 + 0.00002 * m.ALTITUDE) * Ray_extra

    # saturing water vapor pressure (kPa)
    esat = 0.3054 * (exp(17.24 * Tmax / (Tmax + 237.3)) + exp(17.27 * Tmin / (Tmin + 237.3)))
    # partial water vapor pressure (kPa)
    ea = 0.3054 * (exp(17.27 * Tmax / (Tmax + 237.3)) * RHmin / 100 + exp(17.27 * Tmin / (Tmin + 237.3)) * RHmax / 100)

    if (Rg > RGMax)
        ratioRg = 1
    else
        ratioRg = Rg / RGMax
    end
    Rn = 0.77 * Rg - (1.35 * ratioRg - 0.35) * (0.34 - 0.14 * ea^0.5) * ((Tmax + 273.16)^4.0 + (Tmin + 273.16)^4.0) * 2.45015 * (10.0^-9)
    pent_vap_sat = 4098 * (0.6108 * exp(17.27 * TMoy / (TMoy + 237.3))) / (TMoy + 237.3)^2.0
    Kpsy = 0.00163 * 101.3 * (1 - (0.0065 * m.ALTITUDE / 293))^5.26
    # should be KPsy = 0.00163 * 101.3 * std::pow(1 - (0.0065 * Altitude * 1.0 / 293), 5.26) / TLat;
    erad = 0.408 * Rn * pent_vap_sat / (pent_vap_sat + Kpsy * (1 + 0.34 * windspeed))
    eaero = ((900 / (TMoy + 273.16)) * ((esat - ea) * windspeed) * Kpsy) / (pent_vap_sat + Kpsy * (1.0 + 0.34 * windspeed))
    status.ET0 = erad + eaero
end
