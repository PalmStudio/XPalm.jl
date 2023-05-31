struct OrgansCarbonAllocationModel{O} <: AbstractCarbon_AllocationModel
    cost_reserve_mobilization # 1.667
end

OrgansCarbonAllocationModel(cost_reserve_mobilization) = OrgansCarbonAllocationModel{Any}(cost_reserve_mobilization)
OrgansCarbonAllocationModel{O}(; cost_reserve_mobilization=1.667) where {O} = OrgansCarbonAllocationModel{O}(cost_reserve_mobilization)

PlantSimEngine.inputs_(::OrgansCarbonAllocationModel) = (carbon_offer=-Inf, reserve=-Inf,)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel) = (carbon_allocation_organs=-Inf, respiration_reserve_mobilization=-Inf,)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel{T}) where {T<:Union{Leaf,Internode}} = (carbon_allocation=-Inf,)

# At the plant scale:
function PlantSimEngine.run!(m::OrgansCarbonAllocationModel, models, status, meteo, constants, mtg)
    timestep = rownumber(status)

    # Propagate the reserves from the previous day:
    status.reserve = prev_value(status, :reserve, default=status.reserve)

    #! provide Float64 as the type of returned vector here? Or maybe get the type from the status
    # Carbon demand of the organs (internode + leaves):
    carbon_demand = MultiScaleTreeGraph.traverse(mtg, symbol=["Leaf", "Internode"]) do node
        node[:models].status[timestep][:carbon_demand]
    end

    total_carbon_demand_organs = sum(carbon_demand)

    # If the total demand is positive, we try allocating carbon:
    if total_carbon_demand_organs > 0.0
        # Proportion of the demand of each leaf compared to the total leaf demand: 
        proportion_carbon_demand = carbon_demand ./ total_carbon_demand_organs

        if total_carbon_demand_organs <= status.carbon_offer
            # If the carbon demand is lower than the offer we allocate the offer:
            status.carbon_allocation_organs = total_carbon_demand_organs
            status.carbon_offer -= status.carbon_allocation_organs
            reserve_mobilized = 0.0
        else
            reserve_available = status.reserve / m.cost_reserve_mobilization # 1.667
            # Else the plant tries to use its reserves:
            if total_carbon_demand_organs <= status.carbon_offer + reserve_available
                # We allocated the demand because there is enough carbon:
                status.carbon_allocation_organs = total_carbon_demand_organs
                # What we need from the reserves is the demand - what we took from the offer:
                reserve_needed = total_carbon_demand_organs - status.carbon_offer
                # The carbon offer is now 0.0 because we took it first:
                status.carbon_offer = 0.0
                # What is really mobilized is the reserve needed + cost of respiration (mobilization):
                reserve_mobilized = reserve_needed * m.cost_reserve_mobilization
                # The cost of using the reserves is the following respiration:
                status.respiration_reserve_mobilization = reserve_mobilized - reserve_needed
            else
                # Here we don't have enough carbon in reserve + offer so we take all:
                # The reserve that are really available for allocation (- cost of respiration)
                reserve_available = status.reserve / m.cost_reserve_mobilization
                # We only allocate what we have (offer+reserves):
                status.carbon_allocation_organs = status.carbon_offer + reserve_available
                # The carbon offer is now 0.0 because we took all:
                status.carbon_offer = 0.0
                reserve_mobilized = status.reserve
                # The cost of using the reserves is the following respiration:
                status.respiration_reserve_mobilization = reserve_mobilized - reserve_available
            end
        end
        carbon_allocation_organ = status.carbon_allocation_organs .* proportion_carbon_demand
    else
        # If the carbon demand is 0.0, we allocate nothing:
        status.carbon_allocation_organs = 0.0
        carbon_allocation_organ = zeros(typeof(carbon_demand[1]), length(carbon_demand))
        reserve_mobilized = 0.0
    end

    MultiScaleTreeGraph.traverse!(mtg, symbol=["Leaf", "Internode"]) do organ
        organ[:models].status[timestep][:carbon_allocation] =
            popfirst!(carbon_allocation_organ)

        # We propagate the reserve from the day before if we are not at initialisation:
        prev_reserve = prev_value(organ[:models].status[timestep], :reserve, default=organ[:models].status[timestep].reserve)
        if prev_reserve != -Inf
            organ[:models].status[timestep].reserve = prev_reserve
        end
        # else the initialisation set the value for this day already

        # We take the reserve we used at the palm scale using the proportion of reserve that came
        # from that organ (unless there is no reserve anymore, no need to compute, and it would give NaN).
        if status.reserve != 0.0
            organ[:models].status[timestep].reserve -=
                reserve_mobilized * organ[:models].status[timestep].reserve / status.reserve
        end
    end

    # We remove the reserve we mobilized from the reserve pool:
    status.reserve -= reserve_mobilized
end