struct LeavesCarbonAllocationModel <: AbstractCarbon_AllocationModel end

PlantSimEngine.inputs_(::LeavesCarbonAllocationModel) = (carbon_offer=-Inf,)
PlantSimEngine.outputs_(::LeavesCarbonAllocationModel) = (carbon_allocation_leaves=-Inf,)

PlantSimEngine.inputs_(::LeavesCarbonAllocationModel{Leaf}) = (carbon_offer=-Inf,)
PlantSimEngine.outputs_(::LeavesCarbonAllocationModel{Leaf}) = (carbon_allocation=-Inf,)

#! compute it at the leaf scale instead! Using the total leaf demand and then using the proportion 
#! for this leaf in particular.
function PlantSimEngine.run!(::LeavesCarbonAllocationModel{Plant}, models, status, meteo, constants, mtg)
    carbon_demand = MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do leaf
        leaf[:models].status[rownumber(status)][:carbon_demand]
    end

    total_carbon_demand_leaves = sum(carbon_demand)
    # Proportion of the demand of each leaf compared to the total leaf demand: 
    proportion_carbon_demand = carbon_demand ./ total_carbon_demand_leaves
    status.carbon_allocation_leaves = min(total_carbon_demand_leaves, status.carbon_offer)
    carbon_allocation_leaf = status.carbon_allocation_leaves .* proportion_carbon_demand

    MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do leaf
        leaf[:models].status[rownumber(status)][:carbon_allocation] =
            popfirst!(carbon_allocation_leaf)
    end

    status.carbon_offer -= status.carbon_allocation_leaves
end