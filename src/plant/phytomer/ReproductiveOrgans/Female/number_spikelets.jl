"""
    NumberSpikelets(TT_flowering=6300.0, duration_dev_spikelets=675.0)

Determines the number of spikelets on the fruit bunch.

# Arguments

- `TT_flowering`: thermal time for flowering since phytomer appearence (degree days).
- `duration_dev_spikelets`: period of thermal time before flowering that determines the number of spikelets on the fruit bunch (degree days).
"""
struct NumberSpikelets{T} <: AbstractNumber_SpikeletsModel
    TT_flowering::T
    duration_dev_spikelets::T
end

NumberSpikelets(; TT_flowering=6300.0, duration_dev_spikelets=675.0) = NumberSpikelets(TT_flowering, duration_dev_spikelets)

PlantSimEngine.inputs_(::NumberSpikelets) = (carbon_offer_plant=0.0, carbon_demand_plant=0.0, potential_fruits_number=-9999)
PlantSimEngine.outputs_(::NumberSpikelets) = (spikelets_number=-Inf, carbon_demand_spikelets=0.0, carbon_offer_spikelets=0.0, nb_spikelets_flag=false)

# applied at the female inflorescence level
function PlantSimEngine.run!(m::NumberSpikelets, models, status, meteo, constants, extra=nothing)
    status.nb_spikelets_flag && return # We only compute it once

    # We only look into the period of spikelets development :
    if status.TT_since_init >= (m.TT_flowering - m.duration_dev_spikelets)
        # We get the total plant carbon offer and demand from the day before:
        status.carbon_offer_spikelets += status.carbon_offer_plant
        status.carbon_demand_spikelets += status.carbon_demand_plant
        #? Note: carbon_demand_plant is the total carbon demand of all organs in the plant 
        #? from the day before, cumulated between flowering and fruit appearance.
        #? carbon_offer_plant is the equivalent for the offer. They are both used to compute the 
        #? plant trophic status. 
    end

    # At flowering, we determine the number of spikelets:
    if status.TT_since_init >= m.TT_flowering
        # We compute a trophic state of the female inflorescence, with a maximum at 1.0 (no stress)
        trophic_status_spikelets = min(1.0, status.carbon_offer_spikelets / status.carbon_demand_spikelets)
        # We assume that the number of spikelets is proportional to the trophic status of the plant:
        status.spikelets_number = trophic_status_spikelets * status.potential_fruits_number

        # This computation should be done only once because as soon as we know the number of spikelets, it is set for the life of the infrutescence
        status.nb_spikelets_flag = true  # Update the flag
    end
end