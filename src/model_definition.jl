

"""
    model_mapping(p)

Defines the list of sub-models used in XPalm.

# Arguments

- `p`: A palm object with the parameters of the model (*e.g.* p = Palm()).

# Returns

- A multiscale list of models, as a dictionary of scale (keys) and list of models (values).
"""
function model_mapping(p)
    Dict(
        "Scene" => (
            ET0_BP(p.parameters[:plot][:latitude], p.parameters[:plot][:altitude]),
            DailyDegreeDays(),
            MultiScaleModel(
                model=LAIModel(p.parameters[:plot][:scene_area]),
                mapped_variables=[:leaf_areas => ["Plant" => :leaf_area],],
            ),
            Beer(k=p.parameters[:radiation][:k]),
            GraphNodeCount(length(p.mtg)), # to have the `graph_node_count` variable initialised in the status
        ),
        "Plant" => (
            DailyDegreeDays(),
            DailyPlantAgeModel(),
            PhyllochronModel(
                p.parameters[:phyllochron][:age_palm_maturity],
                p.parameters[:phyllochron][:production_speed_initial],
                p.parameters[:phyllochron][:production_speed_mature],
            ),
            MultiScaleModel(
                model=PlantLeafAreaModel(),
                mapped_variables=[:leaf_area_leaves => ["Leaf" => :leaf_area], :leaf_states => ["Leaf" => :state],],
            ),
            MultiScaleModel(
                model=PhytomerEmission(p.mtg),
                mapped_variables=[:graph_node_count => "Scene",],
            ),
            MultiScaleModel(
                model=PlantRm(),
                mapped_variables=[:Rm_organs => ["Leaf", "Internode", "Male", "Female"] .=> :Rm],
            ),
            MultiScaleModel(
                model=SceneToPlantLightPartitioning(p.parameters[:plot][:scene_area]),
                mapped_variables=[:aPPFD_scene => "Scene" => :aPPFD, :scene_leaf_area => "Scene" => :leaf_area],
            ),
            MultiScaleModel(
                model=RUE_FTSW(p.parameters[:radiation][:RUE], p.parameters[:radiation][:threshold_ftsw]),
                mapped_variables=[PreviousTimeStep(:ftsw) => "Soil",],
            ),
            CarbonOfferRm(),
            MultiScaleModel(
                model=OrgansCarbonAllocationModel(p.parameters[:carbon_demand][:reserves][:cost_reserve_mobilization]),
                mapped_variables=[
                    :carbon_demand_organs => ["Leaf", "Internode", "Male", "Female"] .=> :carbon_demand,
                    :carbon_allocation_organs => ["Leaf", "Internode", "Male", "Female"] .=> :carbon_allocation,
                    PreviousTimeStep(:reserve_organs) => ["Leaf", "Internode"] .=> :reserve,
                    PreviousTimeStep(:reserve)
                ],
            ),
            MultiScaleModel(
                model=OrganReserveFilling(),
                mapped_variables=[
                    :potential_reserve_organs => ["Internode", "Leaf"] .=> :potential_reserve,
                    :reserve_organs => ["Internode", "Leaf"] .=> :reserve,
                ],
            ),
            MultiScaleModel(
                model=PlantBunchHarvest(),
                mapped_variables=[
                    :biomass_bunch_harvested_organs => ["Female"] .=> :biomass_bunch_harvested,
                    :biomass_stalk_harvested_organs => ["Female"] .=> :biomass_stalk_harvested,
                    :biomass_fruit_harvested_organs => ["Female"] .=> :biomass_fruit_harvested,
                    :biomass_bunch_harvested_cum_organs => ["Female"] .=> :biomass_bunch_harvested_cum,
                ],
            ),
        ),
        # "Stem" => PlantSimEngine.ModelList(
        #     biomass=StemBiomass(),
        #     variables_check=false,
        #     nsteps=nsteps,
        # ),
        "Phytomer" => (
            MultiScaleModel(
                model=InitiationAgeFromPlantAge(),
                mapped_variables=[:plant_age => "Plant",],
            ),
            # DegreeDaysFTSW(
            #     threshold_ftsw_stress=p.parameters[:phyllochron][:threshold_ftsw_stress],
            # ), #! we should use this one instead of DailyDegreeDaysSinceInit I think
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => "Plant",], # Using TEff computed at plant scale
            ),
            MultiScaleModel(
                model=SexDetermination(
                    TT_flowering=p.parameters[:phenology][:inflorescence][:TT_flowering],
                    duration_abortion=p.parameters[:phenology][:inflorescence][:duration_abortion],
                    duration_sex_determination=p.parameters[:phenology][:inflorescence][:duration_sex_determination],
                    sex_ratio_min=p.parameters[:reproduction][:sex_ratio][:sex_ratio_min],
                    sex_ratio_ref=p.parameters[:reproduction][:sex_ratio][:sex_ratio_ref],
                    random_seed=p.parameters[:reproduction][:sex_ratio][:random_seed],
                ),
                mapped_variables=[
                    PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm,
                    PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand,
                ],
            ),
            MultiScaleModel(
                model=ReproductiveOrganEmission(p.mtg),
                mapped_variables=[:graph_node_count => "Scene", :phytomer_count => "Plant"],
            ),
            MultiScaleModel(
                model=AbortionRate(
                    TT_flowering=p.parameters[:phenology][:inflorescence][:TT_flowering],
                    duration_abortion=p.parameters[:phenology][:inflorescence][:duration_abortion],
                    abortion_rate_max=p.parameters[:reproduction][:abortion][:abortion_rate_max],
                    abortion_rate_ref=p.parameters[:reproduction][:abortion][:abortion_rate_ref],
                    random_seed=p.parameters[:reproduction][:abortion][:random_seed],
                ),
                mapped_variables=[
                    PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm,
                    PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand,
                ],
            ),
            MultiScaleModel(
                model=InfloStateModel(
                    TT_flowering=p.parameters[:phenology][:inflorescence][:TT_flowering],
                    duration_flowering_male=p.parameters[:phenology][:male][:duration_flowering_male],
                    duration_fruit_setting=p.parameters[:phenology][:female][:duration_fruit_setting],
                    duration_bunch_development=p.parameters[:phenology][:female][:duration_bunch_development],
                    fraction_period_oleosynthesis=p.parameters[:phenology][:female][:fraction_period_oleosynthesis],
                ), # Compute the state of the phytomer
                mapped_variables=[:state_organs => ["Leaf", "Male", "Female"] .=> :state,],
                #! note: the mapping is artificial, we compute the state of those organs in the function directly because we use the status of a phytomer to give it to its children
                #! second note: the models should really be associated to the organs (female and male inflo + leaves)
            )
        ),
        "Internode" =>
            (
                MultiScaleModel(
                    model=InitiationAgeFromPlantAge(),
                    mapped_variables=[:plant_age => "Plant",],
                ),
                MultiScaleModel(
                    model=DailyDegreeDaysSinceInit(),
                    mapped_variables=[:TEff => "Plant",], # Using TEff computed at plant scale
                ),
                MultiScaleModel(
                    model=RmQ10FixedN(
                        p.parameters[:respiration][:Internode][:Q10],
                        p.parameters[:respiration][:Internode][:Mr],
                        p.parameters[:respiration][:Internode][:T_ref],
                        p.parameters[:respiration][:Internode][:P_alive],
                    ),
                    mapped_variables=[PreviousTimeStep(:biomass),],
                ),
                FinalPotentialInternodeDimensionModel(
                    p.parameters[:dimensions][:internode][:age_max_height],
                    p.parameters[:dimensions][:internode][:age_max_radius],
                    p.parameters[:dimensions][:internode][:min_height],
                    p.parameters[:dimensions][:internode][:min_radius],
                    p.parameters[:dimensions][:internode][:max_height],
                    p.parameters[:dimensions][:internode][:max_radius],
                ),
                PotentialInternodeDimensionModel(
                    inflexion_point_height=p.parameters[:dimensions][:internode][:inflexion_point_height],
                    slope_height=p.parameters[:dimensions][:internode][:slope_height],
                    inflexion_point_radius=p.parameters[:dimensions][:internode][:inflexion_point_radius],
                    slope_radius=p.parameters[:dimensions][:internode][:slope_radius],
                ),
                InternodeDimensionModel(p.parameters[:carbon_demand][:internode][:apparent_density]),
                InternodeCarbonDemandModel(
                    apparent_density=p.parameters[:carbon_demand][:internode][:apparent_density],
                    carbon_concentration=p.parameters[:carbon_demand][:internode][:carbon_concentration],
                    respiration_cost=p.parameters[:carbon_demand][:internode][:respiration_cost]
                ),
                MultiScaleModel(
                    model=PotentialReserveInternode(
                        p.parameters[:reserves][:nsc_max]
                    ),
                    mapped_variables=[PreviousTimeStep(:biomass), PreviousTimeStep(:reserve)],
                ),
                InternodeBiomass(
                    initial_biomass=p.parameters[:dimensions][:internode][:min_height] * p.parameters[:dimensions][:internode][:min_radius] * p.parameters[:carbon_demand][:internode][:apparent_density],
                    respiration_cost=p.parameters[:carbon_demand][:internode][:respiration_cost]
                ),
            ),
        "Leaf" => (
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => "Plant",], # Using TEff computed at plant scale
            ),
            FinalPotentialAreaModel(
                p.parameters[:dimensions][:leaf][:age_first_mature_leaf],
                p.parameters[:dimensions][:leaf][:leaf_area_first_leaf],
                p.parameters[:dimensions][:leaf][:leaf_area_mature_leaf],
            ),
            PotentialAreaModel(
                p.parameters[:dimensions][:leaf][:inflexion_index],
                p.parameters[:dimensions][:leaf][:slope],
            ),
            MultiScaleModel(
                model=LeafStateModel(),
                mapped_variables=[:rank_leaves => ["Leaf" => :rank], :state_phytomers => ["Phytomer" => :state],],
            ),
            MultiScaleModel(
                model=RankLeafPruning(p.parameters[:management][:rank_leaf_pruning]),
                mapped_variables=[:state_phytomers => ["Phytomer" => :state],],
            ),
            MultiScaleModel(
                model=InitiationAgeFromPlantAge(),
                mapped_variables=[:plant_age => "Plant",],
            ),
            MultiScaleModel(
                model=LeafAreaModel(
                    p.parameters[:mass_and_dimensions][:leaf][:lma_min],
                    p.parameters[:biomass][:leaf][:leaflets_biomass_contribution],
                    p.parameters[:dimensions][:leaf][:leaf_area_first_leaf],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
            MultiScaleModel(
                model=RmQ10FixedN(
                    p.parameters[:respiration][:Leaf][:Q10],
                    p.parameters[:respiration][:Leaf][:Mr],
                    p.parameters[:respiration][:Leaf][:T_ref],
                    p.parameters[:respiration][:Leaf][:P_alive],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
            LeafCarbonDemandModelPotentialArea(
                p.parameters[:mass_and_dimensions][:leaf][:lma_min],
                p.parameters[:carbon_demand][:leaf][:respiration_cost],
                p.parameters[:biomass][:leaf][:leaflets_biomass_contribution]
            ),
            MultiScaleModel(
                model=PotentialReserveLeaf(
                    p.parameters[:mass_and_dimensions][:leaf][:lma_min],
                    p.parameters[:mass_and_dimensions][:leaf][:lma_max],
                    p.parameters[:biomass][:leaf][:leaflets_biomass_contribution]
                ),
                mapped_variables=[PreviousTimeStep(:leaf_area), PreviousTimeStep(:reserve)],
            ),
            LeafBiomass(
                initial_biomass=p.parameters[:dimensions][:leaf][:leaf_area_first_leaf] * p.parameters[:mass_and_dimensions][:leaf][:lma_min] /
                                p.parameters[:biomass][:leaf][:leaflets_biomass_contribution],
                respiration_cost=p.parameters[:carbon_demand][:leaf][:respiration_cost],
            ),
        ),
        "Male" => (
            MultiScaleModel(
                model=InitiationAgeFromPlantAge(),
                mapped_variables=[:plant_age => "Plant",],
            ),
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => "Plant",], # Using TEff computed at plant scale
            ),
            MaleFinalPotentialBiomass(
                p.parameters[:biomass][:male][:max_biomass],
                p.parameters[:phenology][:male][:age_mature_male],
                p.parameters[:biomass][:male][:fraction_biomass_first_male],
            ),
            MultiScaleModel(
                model=RmQ10FixedN(
                    p.parameters[:respiration][:Male][:Q10],
                    p.parameters[:respiration][:Male][:Mr],
                    p.parameters[:respiration][:Male][:T_ref],
                    p.parameters[:respiration][:Male][:P_alive],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
            MaleCarbonDemandModel(
                respiration_cost=p.parameters[:carbon_demand][:male][:respiration_cost],
                duration_flowering_male=p.parameters[:phenology][:male][:duration_flowering_male],
            ),
            MaleBiomass(
                p.parameters[:carbon_demand][:male][:respiration_cost],
            ),
        ),
        "Female" => (
            MultiScaleModel(
                model=InitiationAgeFromPlantAge(),
                mapped_variables=[:plant_age => "Plant",],
            ),
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => "Plant",],
            ),
            MultiScaleModel(
                model=RmQ10FixedN(
                    p.parameters[:respiration][:Female][:Q10],
                    p.parameters[:respiration][:Female][:Mr],
                    p.parameters[:respiration][:Female][:T_ref],
                    p.parameters[:respiration][:Female][:P_alive],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
            FemaleFinalPotentialFruits(
                days_increase_number_fruits=p.parameters[:phenology][:female][:days_increase_number_fruits],
                days_maximum_number_fruits=p.parameters[:phenology][:female][:days_maximum_number_fruits],
                fraction_first_female=p.parameters[:reproduction][:yield_formation][:fraction_first_female],
                potential_fruit_number_at_maturity=p.parameters[:reproduction][:yield_formation][:potential_fruit_number_at_maturity],
                potential_fruit_weight_at_maturity=p.parameters[:reproduction][:yield_formation][:potential_fruit_weight_at_maturity],
                stalk_max_biomass=p.parameters[:reproduction][:yield_formation][:stalk_max_biomass],
            ),
            MultiScaleModel(
                model=NumberSpikelets(
                    TT_flowering=p.parameters[:phenology][:inflorescence][:TT_flowering],
                    duration_dev_spikelets=p.parameters[:phenology][:female][:duration_dev_spikelets],
                ),
                mapped_variables=[PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm, PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand],
            ),
            MultiScaleModel(
                model=NumberFruits(
                    TT_flowering=p.parameters[:phenology][:inflorescence][:TT_flowering],
                    duration_fruit_setting=p.parameters[:phenology][:female][:duration_fruit_setting],
                ),
                mapped_variables=[PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm, PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand],
            ),
            FemaleCarbonDemandModel(
                respiration_cost=p.parameters[:carbon_demand][:female][:respiration_cost],
                respiration_cost_oleosynthesis=p.parameters[:carbon_demand][:female][:respiration_cost_oleosynthesis],
                oil_content=p.parameters[:reproduction][:yield_formation][:oil_content],
                TT_flowering=p.parameters[:phenology][:inflorescence][:TT_flowering],
                duration_bunch_development=p.parameters[:phenology][:female][:duration_bunch_development],
                duration_fruit_setting=p.parameters[:phenology][:female][:duration_fruit_setting],
                fraction_period_oleosynthesis=p.parameters[:phenology][:female][:fraction_period_oleosynthesis],
                fraction_period_stalk=p.parameters[:phenology][:female][:fraction_period_stalk],
            ),
            FemaleBiomass(
                p.parameters[:carbon_demand][:female][:respiration_cost],
                p.parameters[:carbon_demand][:female][:respiration_cost_oleosynthesis],
            ),
            BunchHarvest(),
        ),
        "RootSystem" => (
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => "Scene",], # Using TEff computed at scene scale
            ),
            # root_growth=RootGrowthFTSW(ini_root_depth=p.parameters[:ini_root_depth]),
            # soil_water=FTSW{RootSystem}(ini_root_depth=p.parameters[:ini_root_depth]),
            MultiScaleModel(
                model=RmQ10FixedN(
                    p.parameters[:respiration][:RootSystem][:Q10],
                    p.parameters[:respiration][:RootSystem][:Turn],
                    p.parameters[:respiration][:RootSystem][:Prot],
                    p.parameters[:respiration][:RootSystem][:N],
                    p.parameters[:respiration][:RootSystem][:Gi],
                    p.parameters[:respiration][:RootSystem][:Mx],
                    p.parameters[:respiration][:RootSystem][:T_ref],
                    p.parameters[:respiration][:RootSystem][:P_alive],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
        ),
        "Soil" => (
            # light_interception=Beer{Soil}(),
            MultiScaleModel(
                model=FTSW_BP(
                    ini_root_depth=p.parameters[:water][:ini_root_depth],
                    H_FC=p.parameters[:water][:field_capacity],
                    H_WP_Z1=p.parameters[:water][:wilting_point_1],
                    Z1=p.parameters[:water][:thickness_1],
                    H_WP_Z2=p.parameters[:water][:wilting_point_2],
                    Z2=p.parameters[:water][:thickness_2],
                    H_0=p.parameters[:water][:initial_water_content],
                    KC=p.parameters[:water][:Kc],
                    TRESH_EVAP=p.parameters[:water][:evaporation_threshold],
                    TRESH_FTSW_TRANSPI=p.parameters[:water][:transpiration_threshold],
                ),
                mapped_variables=[:ET0 => "Scene", :aPPFD => "Scene"], # Using TEff computed at scene scale
            ),
            #! Root growth should be in the roots part, but it is a hard-coupled model with 
            #! the FSTW, so we need it here for now.
            MultiScaleModel(
                model=RootGrowthFTSW(ini_root_depth=p.parameters[:water][:ini_root_depth]),
                mapped_variables=[:TEff => "Scene",], # Using TEff computed at scene scale
            ),
        )
    )
end

