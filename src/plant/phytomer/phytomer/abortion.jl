"""
    
    AbortionRate(TT_flowering, duration_abortion, abortion_rate_max=1.0, abortion_rate_ref=0.2; random_seed::Int=0)
    AbortionRate(TT_flowering, duration_abortion, abortion_rate_max, abortion_rate_ref, random_generator<:AbstractRNG)

Determines if the inflorescence will abort based on the trophic state of the plant during a given period in thermal time.

# Arguments 

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_abortion`: duration used for computing abortion rate before flowering (degree days).

# Inputs
- `carbon_offer_plant`: daily plant assimilate offer after maintenance
  respiration (g CH2O-equivalent plant⁻¹ d⁻¹).
- `carbon_demand_plant`: daily total plant assimilate demand
  (g CH2O-equivalent plant⁻¹ d⁻¹).


# Outputs 
- `carbon_demand_abortion`: assimilate demand accumulated over the abortion
  period (g CH2O-equivalent plant⁻¹).
- `carbon_offer_abortion`: assimilate offer accumulated over the abortion
  period (g CH2O-equivalent plant⁻¹).
- `state`: phytomer state (undetermined,Aborted,...)

# Note

The abortion is determined at `TT_flowering` based on the `trophic_status` of the plant during a period of time before this date. The hypothesis is that a trophic stress can trigger more abortion in the plant.
"""
struct AbortionRate{T,R<:AbstractRNG} <: AbstractAbortionModel
    TT_flowering::T
    duration_abortion::T
    abortion_rate_max::T
    abortion_rate_ref::T
    random_generator::R
end

function AbortionRate(; TT_flowering=6300.0, duration_abortion=540.0, abortion_rate_max=0.8, abortion_rate_ref=0.2, random_seed::Int=0)
    AbortionRate(promote(TT_flowering, duration_abortion, abortion_rate_max, abortion_rate_ref)..., MersenneTwister(random_seed))
end

PlantSimEngine.inputs_(::AbortionRate) = (
    TT_since_init=PlantSimEngine.Required(Real),
    carbon_offer_plant=PlantSimEngine.Default(0.0),
    carbon_demand_plant=PlantSimEngine.Default(0.0),
)
PlantSimEngine.outputs_(::AbortionRate) = (state=:undetermined, carbon_demand_abortion=0.0, carbon_offer_abortion=0.0, abortion_calculation_flag=false)
PlantSimEngine.variable_contracts_(::AbortionRate) = (
    carbon_offer_plant=_DAILY_CH2O_EQUIVALENT_FLOW,
    carbon_demand_plant=_DAILY_CH2O_EQUIVALENT_FLOW,
    carbon_demand_abortion=_ACCUMULATED_CH2O_EQUIVALENT,
    carbon_offer_abortion=_ACCUMULATED_CH2O_EQUIVALENT,
)

function PlantSimEngine.run!(m::AbortionRate, status, environment, constants, context)
    status.state == :aborted && return # if abortion is determined, no need to compute it again

    # We only look into the period of abortion :
    if status.TT_since_init > (m.TT_flowering - m.duration_abortion)
        status.carbon_offer_abortion += status.carbon_offer_plant
        status.carbon_demand_abortion += status.carbon_demand_plant
    end

    # Here we have to determine if there is abortion or not:
    if status.TT_since_init > m.TT_flowering && status.abortion_calculation_flag == false
        trophic_status_abortion = status.carbon_offer_abortion / status.carbon_demand_abortion

        # draws a number between 0 and 1 in a uniform distribution:
        random_abort = rand(m.random_generator)

        # Probability to get abortion:
        threshold_abortion = max(
            0.0,
            min(
                m.abortion_rate_max,
                m.abortion_rate_max + trophic_status_abortion * (m.abortion_rate_ref - m.abortion_rate_max)
            )
        )

        #e.g. if threshold_abortion is 0.7 we will have more chance to abort
        if random_abort <= threshold_abortion
            status.state = :aborted
            # Give the state to the reproductive organ:
            phytomer = PlantSimEngine.source_node(context)
            reproductive_organ = phytomer[1][2]
            PlantSimEngine.model_status(context, reproductive_organ).state =
                status.state
        end

        status.abortion_calculation_flag = true  # Update the flag, so that we do not compute it again
    end

    return nothing
end
