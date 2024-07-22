"""
OrgansCarbonAllocationModel()

Compute the carbon to allocate to organs from photosysthesis and reserve mobilization (after maintenance respiration) 


# Arguments

- `cost_reserve_mobilization`: carbon cost to mobilize carbon reserve from stem or leaves

"""
struct OrgansCarbonAllocationModel{T} <: AbstractCarbon_AllocationModel
    cost_reserve_mobilization::T # 1.667
end

OrgansCarbonAllocationModel(; cost_reserve_mobilization=1.667) = OrgansCarbonAllocationModel(cost_reserve_mobilization)

PlantSimEngine.inputs_(::OrgansCarbonAllocationModel) = (carbon_offer_after_rm=-Inf, carbon_demand_organs=[-Inf], reserve=0.0, reserve_organs=[0.0],)
PlantSimEngine.outputs_(::OrgansCarbonAllocationModel) = (carbon_allocation=-Inf, carbon_allocation_organs=[-Inf], respiration_reserve_mobilization=-Inf, carbon_offer_after_allocation=-Inf, carbon_demand=0.0)

# At the plant scale:
function PlantSimEngine.run!(m::OrgansCarbonAllocationModel, models, status, meteo, constants, extra=nothing)
    status.carbon_demand = sum(status.carbon_demand_organs)
    # Trophic status, based on the carbon offer / demand ratio. Note that maintenance respiration 
    # was already removed from the carbon offer here:
    # status.trophic_status = status.carbon_offer_after_rm / status.carbon_demand

    # If the total demand is positive, we try allocating carbon:
    if status.carbon_demand > 0.0
        # Proportion of the demand of each leaf compared to the total leaf demand: 
        proportion_carbon_demand = status.carbon_demand_organs ./ status.carbon_demand

        if status.carbon_demand <= status.carbon_offer_after_rm
            # If the carbon demand is lower than the offer we allocate the offer:
            status.carbon_allocation = status.carbon_demand
            status.carbon_offer_after_allocation = status.carbon_offer_after_rm - status.carbon_allocation
            reserve_mobilized = 0.0
        else
            reserve_available = status.reserve / m.cost_reserve_mobilization # 1.667
            # Else the plant tries to use its reserves:
            if status.carbon_demand <= status.carbon_offer_after_rm + reserve_available
                # We allocated the demand because there is enough carbon:
                status.carbon_allocation = status.carbon_demand
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
                status.carbon_allocation = status.carbon_offer_after_rm + reserve_available
                # The carbon offer is now 0.0 because we took all:
                status.carbon_offer_after_allocation = 0.0
                reserve_mobilized = status.reserve
                # The cost of using the reserves is the following respiration:
                status.respiration_reserve_mobilization = reserve_mobilized - reserve_available
            end
        end
        status.carbon_allocation_organs .= status.carbon_allocation .* proportion_carbon_demand
    else
        # If the carbon demand is 0.0, we allocate nothing:
        status.carbon_allocation = 0.0
        status.carbon_offer_after_allocation = status.carbon_offer_after_rm
        status.carbon_allocation_organs .= zero(eltype(status.carbon_allocation_organs))
        reserve_mobilized = 0.0
    end


    if status.reserve != 0.0
        status.reserve_organs .-= reserve_mobilized .* status.reserve_organs ./ status.reserve
    end

    # We remove the reserve we mobilized from the reserve pool:
    status.reserve -= reserve_mobilized
end