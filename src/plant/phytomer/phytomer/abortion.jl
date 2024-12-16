"""
    
    AbortionRate(TT_flowering, duration_abortion, abortion_rate_max=1.0, abortion_rate_ref=0.2; random_seed::Int=0)
    AbortionRate(TT_flowering, duration_abortion, abortion_rate_max, abortion_rate_ref, random_generator<:AbstractRNG)

Determines if the inflorescence will abort based on the trophic state of the plant during a given period in thermal time.

# Arguments 

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_abortion`: duration used for computing abortion rate before flowering (degree days).

# Inputs
- `carbon_offer_after_rm`: carbon offer after maintenance respiration (gC/plant).
- `carbon_demand_organs`: carbon demand of all organs (gC/plant).


# Outputs 
- `carbon_demand_plant`: total carbon demand of the plant (gC/plant).
- `carbon_offer_plant`: total carbon offer of the plant (gC/plant).
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
    AbortionRate(TT_flowering, duration_abortion, abortion_rate_max, abortion_rate_ref, MersenneTwister(random_seed))
end

PlantSimEngine.inputs_(::AbortionRate) = (TT_since_init=-Inf, carbon_offer_plant=-Inf, carbon_demand_plant=-Inf)
PlantSimEngine.outputs_(::AbortionRate) = (state="undetermined", carbon_demand_abortion=0.0, carbon_offer_abortion=0.0, abortion_calculation_flag=false)

function PlantSimEngine.run!(m::AbortionRate, models, status, meteo, constants, extra=nothing)
    status.state == "Aborted" && return # if abortion is determined, no need to compute it again

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
        if random_abort < threshold_abortion
            status.state = "Aborted"
            # Give the state to the reproductive organ:
            status.node[1][2][:plantsimengine_status].state = status.state
        end

        status.abortion_calculation_flag = true  # Update the flag, so that we do not compute it again
    end

    return nothing
end