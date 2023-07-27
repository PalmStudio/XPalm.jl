"""
    NumberFruits(TT_flowering, duration_dev_fruits)

Determines the number of fruits on the bunch.

# Arguments

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_fruit_setting`: period of thermal time after flowering that determines the number of flowers in the bunch that become fruits, *i.e.* fruit set (degree days).

# Inputs 

- `carbon_offer_after_rm`: carbon offer after maintenance respiration (gC/plant).
- `potential_fruits_number`: potential number of fruits (number/bunch).
- `carbon_demand_plant`: carbon demand of the plant (gC/plant), used to compute the plant trophic status.
- `carbon_offer_plant`: carbon offer of the plant (gC/plant), used to compute the plant trophic status.

# Outputs

- `fruits_number`: number of fruits (number/bunch).
"""
struct NumberFruits{T} <: AbstractNumber_FruitsModel
    TT_flowering::T
    duration_fruit_setting::T
end

PlantSimEngine.inputs_(::NumberFruits) = (carbon_offer_after_rm=-Inf, potential_fruits_number=-9999, carbon_demand_plant=-Inf, carbon_offer_plant=-Inf,)
PlantSimEngine.outputs_(::NumberFruits) = (fruits_number=-9999,)

# applied at the female inflorescence level
function PlantSimEngine.run!(m::NumberFruits, models, status, meteo, constants, node::MultiScaleTreeGraph.Node)

    status.fruits_number = prev_value(status, :fruits_number, default=-9999) # We initialise at the previous value
    status.fruits_number !== -9999 && return # if it has a number of fruits, no need to compute it again

    # We only look into the period of abortion :
    if status.TT_since_init >= m.TT_flowering
        # Propagate the values:
        status.carbon_offer_plant = prev_value(status, :carbon_offer_plant, default=0.0)

        if status.carbon_offer_plant == -Inf
            status.carbon_offer_plant = 0.0
        end

        status.carbon_demand_plant = prev_value(status, :carbon_demand_plant, default=0.0)

        if status.carbon_demand_plant == -Inf
            status.carbon_demand_plant = 0.0
        end

        # We get the total plant carbon offer and demand from the day before:
        timestep = rownumber(status)
        plant_models = MultiScaleTreeGraph.ancestors(node, :models, symbol="Plant")[1]
        plant_status_prev = plant_models.status[timestep-1]
        status.carbon_offer_plant += plant_status_prev[:carbon_offer_after_rm]
        status.carbon_demand_plant += plant_status_prev[:carbon_demand]
        #? Note: carbon_demand_plant is the total carbon demand of all organs in the plant 
        #? from the day before, cumulated between flowering and fruit appearance.
        #? carbon_offer_plant is the equivalent for the offer. They are both used to compute the 
        #? plant trophic status. 
    end

    if status.TT_since_init >= (m.TT_flowering + m.duration_fruit_setting) # At fruit setting
        # We compute a trophic state of the female inflorescence, with a maximum at 1.0 (no stress)
        trophic_status_fruits = min(1.0, status.carbon_offer_plant / status.carbon_demand_plant)
        # We assume that the number of fruits is proportional to the trophic status of the plant:
        status.fruits_number = round(Int, trophic_status_fruits * status.potential_fruits_number)
        #! this computation is only done once because at the end of the day the status will change to "Flowering"
    end
end