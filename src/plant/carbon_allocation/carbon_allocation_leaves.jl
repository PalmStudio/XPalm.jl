struct LeavesCarbonAllocationModel{O} <: AbstractCarbon_AllocationModel end

LeavesCarbonAllocationModel() = LeavesCarbonAllocationModel{Any}()

PlantSimEngine.inputs_(::LeavesCarbonAllocationModel) = (carbon_offer=-Inf,)
PlantSimEngine.outputs_(::LeavesCarbonAllocationModel) = (carbon_allocation_leaves=-Inf,)
PlantSimEngine.outputs_(::LeavesCarbonAllocationModel{Leaf}) = (carbon_allocation=-Inf,)

function PlantSimEngine.run!(::LeavesCarbonAllocationModel, models, status, meteo, constants, mtg)
    timestep = rownumber(status)

    #! provide Float64 as the type of returned vector here? Or maybe get the type from the status
    carbon_demand = MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do leaf
        leaf[:models].status[timestep][:carbon_demand]
    end

    total_carbon_demand_leaves = sum(carbon_demand)
    if total_carbon_demand_leaves > 0.0
        # Proportion of the demand of each leaf compared to the total leaf demand: 
        proportion_carbon_demand = carbon_demand ./ total_carbon_demand_leaves
        status.carbon_allocation_leaves = min(total_carbon_demand_leaves, status.carbon_offer)
        carbon_allocation_leaf = status.carbon_allocation_leaves .* proportion_carbon_demand
    else
        # If the carbon demand is 0.0, we allocate nothing:
        status.carbon_allocation_leaves = 0.0
        carbon_allocation_leaf = zeros(typeof(carbon_demand[1]), length(carbon_demand))
    end

    MultiScaleTreeGraph.traverse!(mtg, symbol="Leaf") do leaf
        leaf[:models].status[timestep][:carbon_allocation] =
            popfirst!(carbon_allocation_leaf)
    end

    status.carbon_offer -= status.carbon_allocation_leaves
end