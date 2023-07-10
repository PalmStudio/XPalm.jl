function main_models_definition(p, nsteps)
    Dict(
        "Scene" => PlantSimEngine.ModelList(
            potential_evapotranspiration=ET0_BP(),
            thermal_time=DailyDegreeDays(),
            lai_dynamic=LAIModel(),
            light_interception=Beer(p[:k]),
            nsteps=nsteps,
        ),
        "Plant" => PlantSimEngine.ModelList(
            # maintenance respiration of organs
            thermal_time=DailyDegreeDays(),
            plant_age=DailyPlantAgeModel(),
            soil_water=FTSW{Plant}(ini_root_depth=p[:ini_root_depth]), # needed to get the ftsw value
            phyllochron=PhyllochronModel(
                p[:phyllochron][:age_palm_maturity],
                p[:phyllochron][:threshold_ftsw_stress],
                p[:phyllochron][:production_speed_initial],
                p[:phyllochron][:production_speed_mature],
            ),
            leaf_area=LeafAreaModel(
                p[:lma_min],
                p[:leaflets_biomass_contribution]
            ),
            phytomer_emission=PhytomerEmission(),
            # Here we put the Rm but we only need it to have the variables at this scale:
            maintenance_respiration=RmQ10FixedN(
                p[:respiration][:Internode][:Q10],
                p[:respiration][:Internode][:Rm_base],
                p[:respiration][:Internode][:T_ref],
                p[:respiration][:Internode][:P_alive],
                p[:nitrogen_content][:Internode],
            ),
            light_interception=Beer{Plant}(p[:k]),
            carbon_assimilation=ConstantRUEModel(p[:RUE]),
            carbon_offer=CarbonOfferRm(),
            # carbon_demand=LeafCarbonDemandModelPotentialArea(
            #     p[:lma_min],
            #     p[:carbon_demand][:leaf][:respiration_cost],
            #     p[:leaflets_biomass_contribution]
            # ),
            carbon_allocation=OrgansCarbonAllocationModel{Plant}(p[:carbon_demand][:reserves][:cost_reserve_mobilization]),
            biomass=LeafBiomass(p[:carbon_demand][:leaf][:respiration_cost]),
            reserve_filling=OrganReserveFilling(
                p[:lma_min],
                p[:lma_max],
                p[:leaflets_biomass_contribution],
                p[:nsc_max]
            ),
            variables_check=false,
            nsteps=nsteps,
        ),
        "Stem" => PlantSimEngine.ModelList(
            biomass=StemBiomass(),
            variables_check=false,
            nsteps=nsteps,
        ),
        "Phytomer" =>
            PlantSimEngine.ModelList(
                #! these models are just taking values from other ones:
                initiation_age=InitiationAgeFromPlantAge(),
                soil_water=FTSW{Phytomer}(ini_root_depth=p[:ini_root_depth]), # needed to get the ftsw value
                carbon_offer=CarbonOfferRm(),
                carbon_allocation=OrgansCarbonAllocationModel{Phytomer}(p[:carbon_demand][:reserves][:cost_reserve_mobilization]),
                #! the previous comment end here
                thermal_time=DegreeDaysFTSW(
                    threshold_ftsw_stress=p[:phyllochron][:threshold_ftsw_stress],
                ),
                leaf_rank=LeafRankModel(),
                leaf_pruning=RankLeafPruning(p[:rank_leaf_pruning]),
                sex_determination=SexDetermination(
                    p[:inflo][:TT_flowering],
                    p[:inflo][:duration_sex_determination],
                    p[:inflo][:duration_abortion],
                    p[:inflo][:sex_ratio_min],
                    p[:inflo][:sex_ratio_ref],
                    random_seed=p[:inflo][:random_seed],
                ),
                reproductive_organ_emission=ReproductiveOrganEmission(),
                abortion=AbortionRate(
                    p[:inflo][:TT_flowering],
                    p[:inflo][:duration_abortion],
                    p[:inflo][:abortion_rate_max],
                    p[:inflo][:abortion_rate_ref],
                    p[:inflo][:random_seed],
                ),
                state=InfloStateModel(
                    p[:inflo][:TT_flowering],
                    p[:inflo][:duration_abortion],
                    p[:male][:duration_flowering_male],
                    p[:female][:TT_harvest],
                    p[:female][:fraction_period_oleosynthesis],
                ),
                variables_check=false,
                status=(initiation_age=0,),
                nsteps=nsteps,
            ),
        "Internode" =>
            PlantSimEngine.ModelList(
                initiation_age=InitiationAgeFromPlantAge(),
                thermal_time=DegreeDaysFTSW(
                    threshold_ftsw_stress=p[:phyllochron][:threshold_ftsw_stress],
                ),
                soil_water=FTSW{Internode}(ini_root_depth=p[:ini_root_depth]), # needed to get the ftsw value
                maintenance_respiration=RmQ10FixedN(
                    p[:respiration][:Internode][:Q10],
                    p[:respiration][:Internode][:Rm_base],
                    p[:respiration][:Internode][:T_ref],
                    p[:respiration][:Internode][:P_alive],
                    p[:nitrogen_content][:Internode],
                ),
                internode_final_potential_dimensions=FinalPotentialInternodeDimensionModel(
                    p[:potential_dimensions][:age_max_height],
                    p[:potential_dimensions][:age_max_radius],
                    p[:potential_dimensions][:min_height],
                    p[:potential_dimensions][:min_radius],
                    p[:potential_dimensions][:max_height],
                    p[:potential_dimensions][:max_radius],
                ),
                internode_potential_dimensions=PotentialInternodeDimensionModel(
                    p[:potential_dimensions][:inflexion_point_height],
                    p[:potential_dimensions][:slope_height],
                    p[:potential_dimensions][:inflexion_point_radius],
                    p[:potential_dimensions][:slope_radius],
                ),
                carbon_demand=InternodeCarbonDemandModel(
                    p[:carbon_demand][:internode][:stem_apparent_density],
                    p[:carbon_demand][:internode][:respiration_cost]
                ),
                carbon_allocation=OrgansCarbonAllocationModel{Internode}(),
                biomass=InternodeBiomass(p[:carbon_demand][:internode][:respiration_cost]),
                internode_dimensions=InternodeDimensionModel(p[:carbon_demand][:internode][:stem_apparent_density]),
                reserve_filling=OrganReserveFilling{Stem}(),
                nsteps=nsteps,
                variables_check=false,
                status=(
                    nitrogen_content=p[:nitrogen_content][:Internode],
                    initiation_age=0
                )
            ),
        "Leaf" => PlantSimEngine.ModelList(
            thermal_time=DegreeDaysFTSW(
                threshold_ftsw_stress=p[:phyllochron][:threshold_ftsw_stress],
            ),
            leaf_final_potential_area=FinalPotentialAreaModel(
                p[:potential_area][:age_first_mature_leaf],
                p[:potential_area][:leaf_area_first_leaf],
                p[:potential_area][:leaf_area_mature_leaf],
            ),
            leaf_potential_area=PotentialAreaModel(
                p[:potential_area][:inflexion_index],
                p[:potential_area][:slope],
            ),
            soil_water=FTSW{Leaf}(ini_root_depth=p[:ini_root_depth]), # needed to get the ftsw value
            state=LeafStateModel(),
            leaf_rank=LeafRankModel(),
            initiation_age=InitiationAgeFromPlantAge(),
            leaf_area=LeafAreaModel(
                p[:lma_min],
                p[:leaflets_biomass_contribution]
            ),
            maintenance_respiration=RmQ10FixedN(
                p[:respiration][:Leaf][:Q10],
                p[:respiration][:Leaf][:Rm_base],
                p[:respiration][:Leaf][:T_ref],
                p[:respiration][:Leaf][:P_alive],
                p[:nitrogen_content][:Leaf]
            ),
            carbon_demand=LeafCarbonDemandModelPotentialArea(
                p[:lma_min],
                p[:carbon_demand][:leaf][:respiration_cost],
                p[:leaflets_biomass_contribution]
            ),
            #! only to have the variable initialised in the status (we put the values from another scale):
            carbon_allocation=OrgansCarbonAllocationModel{Leaf}(),
            # Used at init only:
            # biomass_from_area=BiomassFromArea(
            #     p[:lma_min],
            #     p[:leaflets_biomass_contribution]
            # ),
            # Used after init:
            biomass=LeafBiomass(p[:carbon_demand][:leaf][:respiration_cost]), variables_check=false,
            reserve_filling=OrganReserveFilling{Leaf}(),
            nsteps=nsteps,
            status=(
                nitrogen_content=p[:nitrogen_content][:Leaf],
                initiation_age=0
            )
        ),
        "Male" =>
            PlantSimEngine.ModelList(
                initiation_age=InitiationAgeFromPlantAge(),
                # reproductive_development=ReproductiveDevelopment(
                #     p[:bunch][:age_max_coefficient],
                #     p[:bunch][:min_coefficient],
                #     p[:bunch][:max_coefficient],
                # ),
                thermal_time=DegreeDaysFTSW(
                    threshold_ftsw_stress=p[:phyllochron][:threshold_ftsw_stress],
                ),
                soil_water=FTSW{Male}(ini_root_depth=p[:ini_root_depth]), # needed to get the ftsw value
                final_potential_biomass=MaleFinalPotentialBiomass(
                    p[:male][:male_max_biomass],
                    p[:male][:age_mature_male],
                    p[:male][:fraction_biomass_first_male],
                ),
                maintenance_respiration=RmQ10FixedN(
                    p[:respiration][:Male][:Q10],
                    p[:respiration][:Male][:Rm_base],
                    p[:respiration][:Male][:T_ref],
                    p[:respiration][:Male][:P_alive],
                    p[:nitrogen_content][:Male],
                ),
                state=InfloStateModel(),
                carbon_demand=MaleCarbonDemandModel(
                    p[:male][:duration_flowering_male],
                    p[:inflo][:TT_flowering],
                    p[:carbon_demand][:male][:respiration_cost]
                ),
                carbon_allocation=OrgansCarbonAllocationModel{Male}(),
                biomass=MaleBiomass(
                    p[:carbon_demand][:male][:respiration_cost],
                ),
                variables_check=false,
                nsteps=nsteps,
            ),
        "Female" =>
            PlantSimEngine.ModelList(
                initiation_age=InitiationAgeFromPlantAge(),
                thermal_time=DegreeDaysFTSW(
                    threshold_ftsw_stress=p[:phyllochron][:threshold_ftsw_stress],
                ),
                soil_water=FTSW{Female}(ini_root_depth=p[:ini_root_depth]), # needed to get the ftsw value
                final_potential_biomass=FemaleFinalPotentialFruits(
                    p[:female][:age_mature_female],
                    p[:female][:fraction_first_female],
                    p[:female][:potential_fruit_number_at_maturity],
                    p[:female][:potential_fruit_weight_at_maturity],
                ),
                number_spikelets=NumberSpikelets(
                    p[:inflo][:TT_flowering],
                    p[:female][:duration_dev_spikelets],
                ),
                number_fruits=NumberFruits(
                    p[:inflo][:TT_flowering],
                    p[:female][:duration_fruit_setting],
                ),
                carbon_demand=FemaleCarbonDemandModel(
                    p[:carbon_demand][:female][:respiration_cost],
                    p[:carbon_demand][:female][:respiration_cost_oleosynthesis],
                    p[:inflo][:TT_flowering],
                    p[:female][:TT_harvest],
                    p[:female][:duration_fruit_setting],
                    p[:female][:oil_content],
                    p[:female][:fraction_period_oleosynthesis],
                ),
                biomass=FemaleBiomass(
                    p[:carbon_demand][:female][:respiration_cost],
                    p[:carbon_demand][:female][:respiration_cost_oleosynthesis],
                ),
                state=InfloStateModel(),
                # maintenance_respiration=RmQ10{Female}(p[:Q10], p[:Rm_base], p[:T_ref]),
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
                root_growth=RootGrowthFTSW(ini_root_depth=p[:ini_root_depth]),
                soil_water=FTSW{RootSystem}(ini_root_depth=p[:ini_root_depth]),
                variables_check=false,
                nsteps=nsteps,
                status=(
                    nitrogen_content=p[:nitrogen_content][:RootSystem],
                )
            ),
        "Soil" =>
            PlantSimEngine.ModelList(
                light_interception=Beer{Soil}(),
                soil_water=FTSW(ini_root_depth=p[:ini_root_depth]),
                root_growth=RootGrowthFTSW(ini_root_depth=p[:ini_root_depth]),
                potential_evapotranspiration=ET0_BP(),
                variables_check=false,
                nsteps=nsteps,
                status=(
                    nitrogen_content=p[:nitrogen_content][:RootSystem],
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