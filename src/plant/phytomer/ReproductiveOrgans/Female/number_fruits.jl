"""
    NumberFruits(TT_flowering, duration_dev_fruits)

Determines the number of fruits on the bunch.

# Arguments

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_fruit_setting`: period of thermal time after flowering that determines the number of flowers in the bunch that become fruits, *i.e.* fruit set (degree days).
- `computed`: 

# Inputs 

- `carbon_offer_after_rm`: carbon offer maintenance respiration (gC/plant).
- `potential_fruits_number`: potential number of fruits (number/bunch).
- `carbon_demand_plant`: carbon demand of the plant (gC/plant), used to compute the plant trophic status.
- `carbon_offer_plant`: carbon offer of the plant (gC/plant), used to compute the plant trophic status.

# Outputs

- `fruits_number`: number of fruits (number/bunch).
"""
struct NumberFruits{T} <: AbstractNumber_FruitsModel
    TT_flowering::T
    duration_fruit_setting::T
    is_computed::Ref{Bool}  # Mutable flag using Ref to indicate if the model has been computed already
end

NumberFruits(; TT_flowering=6300.0, duration_fruit_setting=405.0) = NumberFruits(TT_flowering, duration_fruit_setting, Ref(false))

PlantSimEngine.inputs_(::NumberFruits) = (carbon_offer_after_rm=0.0, potential_fruits_number=-9999, carbon_demand_plant=0.0, carbon_offer_plant=-Inf,)
PlantSimEngine.outputs_(::NumberFruits) = (fruits_number=-9999, carbon_offer_flowering=-Inf, carbon_demand_flowering=-Inf,)

# applied at the female inflorescence level
function PlantSimEngine.run!(m::NumberFruits, models, status, meteo, constants, node::MultiScaleTreeGraph.Node)
    m.is_computed[] && return # if it has a number of fruits, no need to compute it again

    # We only look into the period of abortion :
    if status.TT_since_init >= m.TT_flowering
        # We get the total plant carbon offer and demand from the day before:
        status.carbon_offer_flowering += status.carbon_offer_after_rm
        status.carbon_demand_flowering += status.carbon_demand_plant
        #? Note: carbon_demand_plant is the total carbon demand of all organs in the plant 
        #? from the day before, cumulated between flowering and fruit appearance.
        #? carbon_offer_plant is the equivalent for the offer. They are both used to compute the 
        #? plant trophic status. 
    end

    if status.TT_since_init >= (m.TT_flowering + m.duration_fruit_setting) # At fruit setting
        # We compute a trophic state of the female inflorescence, with a maximum at 1.0 (no stress)
        trophic_status_fruits = min(1.0, status.carbon_offer_flowering / status.carbon_demand_flowering)
        # We assume that the number of fruits is proportional to the trophic status of the plant:
        status.fruits_number = round(Int, trophic_status_fruits * status.potential_fruits_number)

        # This computation should be done only once because as soon as we know the number of fruits, it is set for the life of the infrutescence
        m.is_computed[] = true  # Update the flag
    end
end