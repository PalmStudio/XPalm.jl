function main_models_definition()
    Dict(
        "Palm" => ModelList(
            # maintenance respiration of organs
            Rm=RmQ10{Palm}(),
        ),
        # "Soil" => ModelList(
        #     soil_model=FTSW(), #! Add parameters here
        # ),
        "Phytomer" =>
            ModelList(
                Rm=Maintenance_Q10(),
                status=(d=0.03,)
            ),
        "Internode" =>
            ModelList(
                Rm=Maintenance_Q10(),
                status=(d=0.03,)
            ),
        "Leaf" =>
            ModelList(
                Rm=Maintenance_Q10(),
                status=(d=0.03,)
            ),
        "Male" =>
            ModelList(
                Rm=Maintenance_Q10(),
                status=(d=0.03,)
            ),
        "Female" =>
            ModelList(
                Rm=Maintenance_Q10(),
                status=(d=0.03,)
            )
    )
end

# function main_models_definition()
#     models = Dict(
#         "Palm" => ModelList(
#             # maintenance respiration of organs
#             Rm=RmQ10{Palm}(),
#             # Allocation of maintenance respiration (eventually with mortality)
#             c_allocate_Rm=AllocateRm_palm(),
#             # mortality of organs due to maintenance respiration not fullfilled
#             Mortality_Rm=RmMortality(),
#             # Offer in carbon for growth, photosynthesis - c_allocate_Rm
#             c_offer=CarbonOffer_Phytomer(),
#             # demand for carbon at the organ scale, then summed for each organ type:
#             c_demand=Demand(),
#             # allocation of carbon, min(Offer,Demand), with Offer == Photosynthesis
#             # first use photosynthesis, then reserves if not enough:
#             c_allocation=Allocation_common_pool(),
#             Rg=Rg(), # growth respiration (construction cost, for each organ)
#             NPP=NPP(), # Net Primary Production of the organ (daily biomass increment)
#             biomass=Update_Biomass(), # Biomass + NPP, at organ scale
#             # If some assimilated are left, we put them in the reserves:
#             reserves=Reserves(),
#         ),
#         "Soil" => ModelList(
#             soil_model=FTSW(), #! Add parameters here
#         ),
#         "Phytomer" =>
#             ModelList(
#                 Rm=Maintenance_Q10(),
#                 c_demand=Demand(),
#                 Rg=Rg(), # growth respiration (construction cost, for each organ)
#                 NPP=NPP(), # Net Primary Production of the organ (daily biomass increment)
#                 biomass=Update_Biomass(), # Biomass + NPP, at organ scale
#                 status=(d=0.03,)
#             ),
#         "Internode" =>
#             ModelList(
#                 Rm=Maintenance_Q10(),
#                 c_demand=Demand(),
#                 Rg=Rg(), # growth respiration (construction cost, for each organ)
#                 NPP=NPP(), # Net Primary Production of the organ (daily biomass increment)
#                 biomass=Update_Biomass(), # Biomass + NPP, at organ scale
#                 status=(d=0.03,)
#             ),
#         "Leaf" =>
#             ModelList(
#                 energy_balance=Monteith(),
#                 photosynthesis=Fvcb(),
#                 stomatal_conductance=Medlyn(0.03, 12.0),
#                 Rm=Maintenance_Q10(),
#                 c_demand=Demand(),
#                 Rg=Rg(), # growth respiration (construction cost, for each organ)
#                 NPP=NPP(), # Net Primary Production of the organ (daily biomass increment)
#                 biomass=Update_Biomass(), # Biomass + NPP, at organ scale
#                 status=(d=0.03,)
#             ),
#         "Male" =>
#             ModelList(
#                 Rm=Maintenance_Q10(),
#                 c_demand=Demand(),
#                 Rg=Rg(), # growth respiration (construction cost, for each organ)
#                 NPP=NPP(), # Net Primary Production of the organ (daily biomass increment)
#                 biomass=Update_Biomass(), # Biomass + NPP, at organ scale
#                 status=(d=0.03,)
#             ),
#         "Female" =>
#             ModelList(
#                 Rm=Maintenance_Q10(),
#                 c_demand=Demand(),
#                 Rg=Rg(), # growth respiration (construction cost, for each organ)
#                 NPP=NPP(), # Net Primary Production of the organ (daily biomass increment)
#                 biomass=Update_Biomass(), # Biomass + NPP, at organ scale
#                 status=(d=0.03,)
#             )
#     )
# end