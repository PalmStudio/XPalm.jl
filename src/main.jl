
# Everything is computed at organ scale, and then aggregated to the phytomer scale,
# then to the palm scale.
function init_palm(palm::Palm, meteo, parameter)

end

function XPalm()
    PlantBiophysics.ModelList(
        photosynthesis=FcVB(),
        # stomatal_conductance=BallBerry(),
        # leaf_energy_balance=LeafEnergyBalance(),
        # maintenance respiration of organs
        Rm=Maintenance_Q10(),
        # Allocation of maintenance respiration (eventually with mortality)
        c_allocate_Rm=AllocateRm(),
        # mortality of organs due to maintenance respiration not fullfilled
        Mortality_Rm=RmMortality(),
        # Offer in carbon for growth, photosynthesis - c_allocate_Rm
        c_offer=CarbonOffer_Phytomer(),
        # demand for carbon at the organ scale, then summed for each organ type:
        c_demand=Demand(),
        # allocation of carbon, min(Offer,Demand), with Offer == Photosynthesis
        # first use photosynthesis, then reserves if not enough:
        c_allocation=Allocation_common_pool(),
        Rg=Rg(), # growth respiration (construction cost, for each organ)
        NPP=NPP(), # Net Primary Production of the organ (daily biomass increment)
        biomass=Update_Biomass(), # Biomass + NPP, at organ scale
        # If some assimilated are left, we put them in the reserves:
        reserves=Reserves(),
        status=Status(), # Initialisations
    )
end

function run(palm::Palm, meteo, parameters)
    CarbonOffer_Phytomer()
end


function CarbonOffer_Pool()
    kldhfdfqdofijofimud
end

function CarbonOffer_Phytomer()
    kldhfdfqdofijofimud
end