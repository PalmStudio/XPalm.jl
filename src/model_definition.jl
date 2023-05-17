function main_models_definition(p, nsteps)
    Dict(
        "Scene" => PlantSimEngine.ModelList(
            potential_evapotranspiration=ET0_BP(),
            thermal_time=DailyDegreeDays(),
            nsteps=nsteps,
        ),
        "Palm" => PlantSimEngine.ModelList(
            # maintenance respiration of organs
            maintenance_respiration=RmQ10{Palm}(p[:Q10], p[:Rm_base], p[:T_ref]),
            variables_check=false,
            nsteps=nsteps,
        ),
        "Stem" => PlantSimEngine.ModelList(
            # maintenance respiration of organs
            maintenance_respiration=RmQ10{Stem}(p[:Q10], p[:Rm_base], p[:T_ref]),
            variables_check=false,
            nsteps=nsteps,
        ),
        "Phytomer" =>
            PlantSimEngine.ModelList(
                maintenance_respiration=RmQ10{Phytomer}(p[:Q10], p[:Rm_base], p[:T_ref]),
                variables_check=false,
                status=(initiation_day=0,),
                nsteps=nsteps,
            ),
        "Internode" =>
            PlantSimEngine.ModelList(
                maintenance_respiration=RmQ10{Internode}(p[:Q10], p[:Rm_base], p[:T_ref]),
                variables_check=false,
                nsteps=nsteps,
                status=(
                    nitrogen_content=p[:nitrogen_content][:Internode],
                    initiation_day=0
                )
            ),
        "Leaf" => PlantSimEngine.ModelList(
            maintenance_respiration=RmQ10{Leaf}(p[:Q10], p[:Rm_base], p[:T_ref]),
            leaf_potential_area=Potential_AreaModel_BP(
                p[:potential_area][:age_first_mature_leaf],
                p[:potential_area][:leaf_area_first_leaf],
                p[:potential_area][:leaf_area_mature_leaf],
            ),
            # phyllochron=PhyllochronModel(), #! continue here
            variables_check=false,
            nsteps=nsteps,
            status=(
                nitrogen_content=p[:nitrogen_content][:Leaf],
                initiation_day=0
            )
        ),
        "Male" =>
            PlantSimEngine.ModelList(
                maintenance_respiration=RmQ10{Male}(p[:Q10], p[:Rm_base], p[:T_ref]),
                variables_check=false,
                nsteps=nsteps,
            ),
        "Female" =>
            PlantSimEngine.ModelList(
                maintenance_respiration=RmQ10{Female}(p[:Q10], p[:Rm_base], p[:T_ref]),
                variables_check=false,
                nsteps=nsteps,
                status=(
                    nitrogen_content=p[:nitrogen_content][:Female],
                )
            ),
        "RootSystem" =>
            PlantSimEngine.ModelList(
                potential_evapotranspiration=ET0_BP(),
                thermal_time=DailyDegreeDays(),
                maintenance_respiration=RmQ10{RootSystem}(p[:Q10], p[:Rm_base], p[:T_ref]),
                root_growth=RootGrowthFTSW(ini_root_depth=p[:ini_root_depth]),
                soil_water=FTSW(ini_root_depth=p[:ini_root_depth]),
                variables_check=false,
                nsteps=nsteps,
                status=(
                    nitrogen_content=p[:nitrogen_content][:RootSystem],
                    #! to remove when we have the computation of light:
                    tree_ei=0.8,
                )
            ),
        "Soil" =>
            PlantSimEngine.ModelList(
                soil_water=FTSW(ini_root_depth=p[:ini_root_depth]),
                potential_evapotranspiration=ET0_BP(),
                variables_check=false,
                nsteps=nsteps,
                status=(
                    nitrogen_content=p[:nitrogen_content][:RootSystem],
                    #! to remove when we have the computation of light:
                    tree_ei=0.8,
                )
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
#         :Internode =>
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
#         :Female =>
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