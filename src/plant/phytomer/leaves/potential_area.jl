"""
    PotentialAreaModel(inflexion_index, slope)
    PotentialAreaModel(inflexion_index=  560.0, slope=100.0)

Computes the instantaneous potential area at a given cumulative thermal time using 
a [logistic function](https://en.wikipedia.org/wiki/Logistic_function). In other words,
it defines the development of the leaf area at the potential, *i.e.* without any stress. 
It starts around 0.0 and goes to a maximum of `final_potential_area`.

# Arguments

- `inflexion_index`: a parameter that defines the relationship between the final potential
leaf area and the inflexion point of the logistic function. The higher the final area, the 
longer the time to reach the inflexion point.
- `slope`: the slope of the relationship at the inflexion point.

# Inputs
- `final_potential_area`: the final potential area when the leaf is fully developed
- `TT_since_init`: the cumulated thermal time since leaf initiation

# Outputs
- `potential_area`: potential area of the leaf (m2)
- `maturity`: maturity is true when the leaf reaches its final length

"""
struct PotentialAreaModel{T} <: AbstractLeaf_Potential_AreaModel
    inflexion_index::T
    slope::T
end

PlantSimEngine.inputs_(::PotentialAreaModel) = (TT_since_init=-Inf, final_potential_area=-Inf,)

PlantSimEngine.outputs_(::PotentialAreaModel) = (
    potential_area=0.0, # Potential area (during leaf development)
    increment_potential_area=-Inf,
    maturity=false,      # Leaf maturity state (true if the leaf is mature)
)

function PlantSimEngine.run!(m::PotentialAreaModel, models, status, meteo, constants, extra=nothing)
    # This is the daily potential area of the leaf (should be computed once only...)
    inflexion_point = max(status.final_potential_area * m.inflexion_index, 27.0)

    new_potential_area =
        status.final_potential_area / (1.0 + exp(-(status.TT_since_init - inflexion_point) / m.slope))
    # Note: TT_since_init is the one from the leaf, it may be corrected by stresses (e.g. ftsw)
    # see the model used for the thermal_time process for the leaf

    status.increment_potential_area = new_potential_area - status.potential_area
    status.potential_area = new_potential_area
    if status.TT_since_init > inflexion_point * 2.0
        status.maturity = true
    end
end