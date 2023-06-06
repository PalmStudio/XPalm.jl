"""
    SexDetermination(TT_flowering,duration_abortion,duration_sex_determination)

Determines the sex of a phytomer -or rather, its bunch- based on the trophic 
state of the plant during a given period in thermal time.

# Arguments 
- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_abortion`: duration used for computing abortion rate before flowering (degree days).
- `duration_sex_determination`: duration used for sex determination before the abortion period(degree days).

# Note

#---duration_sex_determination---/---duration_abortion---/TT_flowering

The sex of the organ is determined at `TT_flowering-duration_abortion` based on the `trophic_status` of the plant during a period of time 
before this date. The hypothesis is that a trophic stress can trigger more males in the plant.
"""
struct SexDetermination{T} <: AbstractSex_DeterminationModel
    TT_flowering::T
    duration_abortion::T
    duration_sex_determination::T
    sex_ratio_min::T
    sex_ratio_ref::T
    random_seed::Int
end

function SexDetermination(TT_flowering, duration_abortion, duration_sex_determination)
    SexDetermination(TT_flowering, duration_abortion, duration_sex_determination, 1)
end

PlantSimEngine.inputs_(::SexDetermination) = (carbon_offer_after_rm=-Inf, carbon_demand_organs=-Inf)
PlantSimEngine.outputs_(::SexDetermination) = (sex="undetermined", carbon_demand_sex_determination=-Inf, carbon_offer_sex_determination=-Inf,)

function PlantSimEngine.run!(m::SexDetermination, models, status, meteo, constants, extra=nothing)

    status.sex = prev_value(status, :sex, default="undetermined")
    status.sex != "undetermined" && return # if the sex is already determined, no need to compute it again

    # We only look into the period that begin at TT_since_init - period and end at TT_since_init:
    if status.TT_since_init > (m.TT_flowering - m.duration_abortion - m.duration_sex_determination)
        # Propagate the values:
        status.carbon_offer_sex_determination =
            prev_value(status, :carbon_offer_sex_determination, default=0.0)

        if status.carbon_offer_sex_determination == -Inf
            status.carbon_offer_sex_determination = 0.0
        end

        status.carbon_demand_sex_determination =
            prev_value(status, :carbon_demand_sex_determination, default=0.0)

        if status.carbon_demand_sex_determination == -Inf
            status.carbon_demand_sex_determination = 0.0
        end

        status.carbon_offer_sex_determination += status.carbon_offer_after_rm
        status.carbon_demand_sex_determination += status.carbon_demand
    end

    # Here we have to determine the sex:
    if status.TT_since_init > (m.TT_flowering - m.duration_abortion)
        trophic_status_sex_determination = status.carbon_offer_sex_determination / status.carbon_demand_sex_determination

        # draws a number between 0 and 1 in a uniform distribution:
        random_sex = rand(MersenneTwister(m.random_seed))

        # Probability to get a female:
        threshold_sex = max(
            0.0,
            min(
                0.9,
                m.sex_ratio_min + trophic_status_sex_determination * (m.sex_ratio_ref - m.sex_ratio_min)
            )
        )

        #e.g. if threshold_sex is 0.7 we will have more chance to have a female
        if random_sex < threshold_sex
            status.sex = "female"
        else
            status.sex = "male"
        end
    end
end