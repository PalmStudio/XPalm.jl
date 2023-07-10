struct OrgansCarbonAllocationModel{O} <: AbstractCarbon_AllocationModel
    cost_reserve_mobilization # 1.667
end

OrgansCarbonAllocationModel(cost_reserve_mobilization) = OrgansCarbonAllocationModel{Any}(cost_reserve_mobilization)
OrgansCarbonAllocationModel{O}(; cost_reserve_mobilization=1.667) where {O} = OrgansCarbonAllocationModel{O}(cost_reserve_mobilization)

PlantSimEngine.inputs_(::OrgansCarbonAllocationModel) = (carbon_offer_after_rm=-Inf,)#, reserve=-Inf,)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel) = (carbon_allocation_organs=-Inf, respiration_reserve_mobilization=-Inf, trophic_status=-Inf, carbon_offer_after_allocation=-Inf, carbon_demand=-Inf)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel{T}) where {T<:Union{Leaf,Internode,Male,Female}} = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel{Phytomer}) = (carbon_demand=-Inf,)

# At the plant scale:
function PlantSimEngine.run!(m::OrgansCarbonAllocationModel{Plant}, models, status, meteo, constants, mtg)
    timestep = rownumber(status)

    # Propagate the reserves from the previous day:
    status.reserve = prev_value(status, :reserve, default=status.reserve)

    #! provide Float64 as the type of returned vector here? Or maybe get the type from the status
    # Carbon demand of the organs (internode + leaves):
    carbon_demand_organs = MultiScaleTreeGraph.traverse(mtg, symbol=["Leaf", "Internode", "Male", "Female"]) do node
        node[:models].status[timestep][:carbon_demand]
    end

    status.carbon_demand = sum(carbon_demand_organs)

    # Trophic status, based on the carbon offer / demand ratio. Note that maintenance respiration 
    # was already removed from the carbon offer here:
    # status.trophic_status = status.carbon_offer_after_rm / status.carbon_demand

    # If the total demand is positive, we try allocating carbon:
    if status.carbon_demand > 0.0
        # Proportion of the demand of each leaf compared to the total leaf demand: 
        proportion_carbon_demand = carbon_demand_organs ./ status.carbon_demand

        if status.carbon_demand <= status.carbon_offer_after_rm
            # If the carbon demand is lower than the offer we allocate the offer:
            status.carbon_allocation_organs = status.carbon_demand
            status.carbon_offer_after_allocation = status.carbon_offer_after_rm - status.carbon_allocation_organs
            reserve_mobilized = 0.0
        else
            reserve_available = status.reserve / m.cost_reserve_mobilization # 1.667
            # Else the plant tries to use its reserves:
            if status.carbon_demand <= status.carbon_offer_after_rm + reserve_available
                # We allocated the demand because there is enough carbon:
                status.carbon_allocation_organs = status.carbon_demand
                # What we need from the reserves is the demand - what we took from the offer:
                reserve_needed = status.carbon_demand - status.carbon_offer_after_rm
                # The carbon offer is now 0.0 because we took it first:
                status.carbon_offer_after_allocation = 0.0
                # What is really mobilized is the reserve needed + cost of respiration (mobilization):
                reserve_mobilized = reserve_needed * m.cost_reserve_mobilization
                # The cost of using the reserves is the following respiration:
                status.respiration_reserve_mobilization = reserve_mobilized - reserve_needed
            else
                # Here we don't have enough carbon in reserve + offer so we take all:
                # We only allocate what we have (offer+reserves):
                status.carbon_allocation_organs = status.carbon_offer_after_rm + reserve_available
                # The carbon offer is now 0.0 because we took all:
                status.carbon_offer_after_allocation = 0.0
                reserve_mobilized = status.reserve
                # The cost of using the reserves is the following respiration:
                status.respiration_reserve_mobilization = reserve_mobilized - reserve_available
            end
        end
        carbon_allocation_organ = status.carbon_allocation_organs .* proportion_carbon_demand
    else
        # If the carbon demand is 0.0, we allocate nothing:
        status.carbon_allocation_organs = 0.0
        status.carbon_offer_after_allocation = status.carbon_offer_after_rm
        carbon_allocation_organ = zeros(typeof(carbon_demand_organs[1]), length(carbon_demand_organs))
        reserve_mobilized = 0.0
    end


    MultiScaleTreeGraph.traverse!(mtg, symbol=["Leaf", "Internode", "Male", "Female"]) do organ
        organ[:models].status[timestep][:carbon_allocation] =
            popfirst!(carbon_allocation_organ)

        # Reserves only for leaves and internodes:    
        if hasproperty(organ[:models].status, :reserve)
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
    end

    # We remove the reserve we mobilized from the reserve pool:
    status.reserve -= reserve_mobilized
end


# Get values from phytomer (do not use for leaves and internode, they get their values from the Plant model already):
function PlantSimEngine.run!(::OrgansCarbonAllocationModel{Phytomer}, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    scene = get_root(mtg)
    timestep = rownumber(status)
    MultiScaleTreeGraph.traverse(scene, symbol="Plant") do plant
        status.carbon_demand = plant[:models].status[timestep].carbon_demand
    end
end