struct OrgansCarbonAllocationModel{O} <: AbstractCarbon_AllocationModel end

OrgansCarbonAllocationModel() = OrgansCarbonAllocationModel{Any}()

PlantSimEngine.inputs_(::OrgansCarbonAllocationModel) = (carbon_offer=-Inf,)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel) = (carbon_allocation_organs=-Inf,)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel{T}) where {T<:Union{Leaf,Internode}} = (carbon_allocation=-Inf,)

# At the plant scale:
function PlantSimEngine.run!(::OrgansCarbonAllocationModel, models, status, meteo, constants, mtg)
    timestep = rownumber(status)

    #! provide Float64 as the type of returned vector here? Or maybe get the type from the status
    # Carbon demand of the organs (internode + leaves):
    carbon_demand = MultiScaleTreeGraph.traverse(mtg, symbol=["Leaf", "Internode"]) do node
        node[:models].status[timestep][:carbon_demand]
    end

    total_carbon_demand_organs = sum(carbon_demand)
    if total_carbon_demand_organs > 0.0
        # Proportion of the demand of each leaf compared to the total leaf demand: 
        proportion_carbon_demand = carbon_demand ./ total_carbon_demand_organs
        status.carbon_allocation_organs = min(total_carbon_demand_organs, status.carbon_offer)
        carbon_allocation_organ = status.carbon_allocation_organs .* proportion_carbon_demand
    else
        # If the carbon demand is 0.0, we allocate nothing:
        status.carbon_allocation_organs = 0.0
        carbon_allocation_organ = zeros(typeof(carbon_demand[1]), length(carbon_demand))
    end

    MultiScaleTreeGraph.traverse!(mtg, symbol=["Leaf", "Internode"]) do organ
        organ[:models].status[timestep][:carbon_allocation] =
            popfirst!(carbon_allocation_organ)
    end

    status.carbon_offer -= status.carbon_allocation_organs
end