"""
    SexDetermination(TT_flowering, duration_abortion, duration_sex_determination, sex_ratio_min, sex_ratio_ref, rng)
    SexDetermination(TT_flowering, duration_abortion, duration_sex_determination, sex_ratio_min, sex_ratio_ref; random_seed=1)

Determines the sex of a phytomer -or rather, its bunch- based on the trophic 
state of the plant during a given period in thermal time.

# Arguments 

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_abortion`: duration used for computing abortion rate before flowering (degree days).
- `duration_sex_determination`: duration used for sex determination before the abortion period(degree days).
- `sex_ratio_min`: minimum allowed threshold of the sex ratio.
- `sex_ratio_ref`: reference threshold of the sex ratio, *i.e.* the value when the trophic status is 1 (offer=demand).
- `rng`: random number generator, `Random.MersenneTwister` by default.
- `random_seed`: random seed for the random number generator, 1 by default.

# Inputs

- `carbon_offer_plant`: carbon offer at the plant scale (usually after maintenance respiration) (gC/plant).
- `carbon_demand_plant`: total carbon demand of the plant (gC/plant), used to compute the plant trophic status.

# Outputs

- `sex`: the sex of the phytomer (or bunch) (:undetermined, :Female or :Male).
- `carbon_demand_sex_determination`: carbon demand of the plant integrated over the period of sex determination (gC/plant)
- `carbon_offer_sex_determination`: carbon offer of the plant integrated over the period of sex determination (gC/plant)

# Note

The sex of the organ is determined at `TT_flowering-duration_abortion` based on the `trophic_status` of the plant during a period of time 
before this date. The hypothesis is that a trophic stress can trigger more males in the plant.
"""
struct SexDetermination{T,R<:AbstractRNG} <: AbstractSex_DeterminationModel
    TT_flowering::T
    duration_abortion::T
    duration_sex_determination::T
    sex_ratio_min::T
    sex_ratio_ref::T
    rng::R
end

function SexDetermination(; TT_flowering=6300.0, duration_abortion=540.0, duration_sex_determination=1350.0, sex_ratio_min=0.2, sex_ratio_ref=0.6, random_seed=1)
    @assert sex_ratio_ref > sex_ratio_min "`sex_ratio_ref` must be greater than `sex_ratio_min`"
    @assert sex_ratio_min > 0.0 "`sex_ratio_min` must be greater than 0.0"
    SexDetermination(promote(TT_flowering, duration_abortion, duration_sex_determination, sex_ratio_min, sex_ratio_ref)..., MersenneTwister(random_seed))
end

PlantSimEngine.inputs_(::SexDetermination) = (TT_since_init=-Inf, carbon_offer_plant=-Inf, carbon_demand_plant=-Inf)
PlantSimEngine.outputs_(::SexDetermination) = (sex=:undetermined, carbon_demand_sex_determination=0.0, carbon_offer_sex_determination=0.0,)
PlantSimEngine.dep(::SexDetermination) = (reproductive_organ_emission=AbstractReproductive_Organ_EmissionModel,)

function PlantSimEngine.run!(m::SexDetermination, models, status, meteo, constants, extra=nothing)
    status.sex != :undetermined && return # if the sex is already determined, no need to compute it again
    status.state == :aborted && return # if the phytomer is aborted, no reproductive organ can be emitted  
    status.state == :harvested && return # no need to compute if harvested (e.g. the leaf was removed)

    # We only look into the period of sex determination:
    if status.TT_since_init > (m.TT_flowering - m.duration_abortion - m.duration_sex_determination)
        status.carbon_offer_sex_determination += status.carbon_offer_plant
        status.carbon_demand_sex_determination += status.carbon_demand_plant
    end

    # Here we have to determine the sex:
    if status.TT_since_init > (m.TT_flowering - m.duration_abortion)
        trophic_status_sex_determination = status.carbon_offer_sex_determination / status.carbon_demand_sex_determination

        # draws a number between 0 and 1 in a uniform distribution:
        random_sex = rand(m.rng)

        # Probability to get a female:
        threshold_sex =
            min(
                0.9,
                m.sex_ratio_min + trophic_status_sex_determination * (m.sex_ratio_ref - m.sex_ratio_min)
            )
        #! threshold_sex was max(0.0,threshold_sex) in the original code, but this is not needed as trophic_status_sex_determination cannot be negative, and m.sex_ratio_min must be >= 0.0

        #e.g. if threshold_sex is 0.7 we will have more chance to have a female
        if random_sex < threshold_sex
            status.sex = :Female
        else
            status.sex = :Male
        end

        PlantSimEngine.run!(models.reproductive_organ_emission, models, status, meteo, constants, extra)
    end
end