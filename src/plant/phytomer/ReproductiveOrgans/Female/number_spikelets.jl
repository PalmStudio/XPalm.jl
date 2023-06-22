"""
    NumberSpikelets(TT_flowering, duration_dev_spikelets)

Determines the number of spikelets on the fruit bunch.

# Arguments

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_dev_spikelets`: period of thermal time before flowering that determines the number of spikelets on the fruit bunch (degree days).
"""
struct NumberSpikelets{T} <: AbstractNumber_SpikeletsModel
    TT_flowering::T
    duration_dev_spikelets::T
end

PlantSimEngine.inputs_(::NumberSpikelets) = (carbon_offer_after_rm=-Inf, carbon_demand_organs=-Inf, potential_fruits_number=-Inf)
PlantSimEngine.outputs_(::NumberSpikelets) = (spikelets_number=-Inf, carbon_demand_spikelets=-Inf, carbon_offer_spikelets=-Inf,)

# applied at the female inflorescence level
function PlantSimEngine.run!(m::NumberSpikelets, models, status, meteo, constants, node::MultiScaleTreeGraph.Node)

    status.spikelets_number = prev_value(status, :spikelets_number, default=-Inf)
    status.spikelets_number !== -Inf && return # if it has a some spikelets, no need to compute it again

    # We only look into the period of spikelets development :
    if status.TT_since_init >= (m.TT_flowering - m.duration_dev_spikelets)
        # Propagate the values:
        status.carbon_offer_spikelets =
            prev_value(status, :carbon_offer_spikelets, default=0.0)

        if status.carbon_offer_spikelets == -Inf
            status.carbon_offer_spikelets = 0.0
        end

        status.carbon_demand_spikelets =
            prev_value(status, :carbon_demand_spikelets, default=0.0)

        if status.carbon_demand_spikelets == -Inf
            status.carbon_demand_spikelets = 0.0
        end

        # We get the total plant carbon offer and demand from the day before:
        timestep = rownumber(status)
        plant_models = MultiScaleTreeGraph.ancestors(node, :models, symbol="Plant")[1]
        plant_status_prev = plant_models.status[timestep-1]
        status.carbon_offer_spikelets += plant_status_prev[:carbon_offer_after_rm]
        status.carbon_demand_spikelets += plant_status_prev[:carbon_demand]
        #? Note: carbon_demand_fruits is the total carbon demand of all organs in the plant 
        #? from the day before, cumulated between flowering and fruit appearance.
        #? carbon_offer_fruits is the equivalent for the offer. They are both used to compute the 
        #? plant trophic status. 
    end

    # At flowering, we determine the number of spikelets:
    if status.TT_since_init >= m.TT_flowering
        # We compute a trophic state of the female inflorescence, with a maximum at 1.0 (no stress)
        trophic_status_spikelets = min(1.0, status.carbon_offer_spikelets / status.carbon_demand_spikelets)
        # We assume that the number of spikelets is proportional to the trophic status of the plant:
        status.spikelets_number = trophic_status_spikelets * status.potential_fruits_number
        #! this computation is only done once because at the end of the day the status will change to "Flowering"
    end
end