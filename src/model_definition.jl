

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
            ET0_BP(p.parameters[:latitude], p.parameters[:altitude]),
            DailyDegreeDays(),
            MultiScaleModel(
                model=LAIModel(p.parameters[:scene_area]),
                mapping=[:leaf_areas => ["Plant" => :leaf_area],],
            ),
            Beer(k=p.parameters[:k]),
            GraphNodeCount(length(p.mtg)), # to have the `graph_node_count` variable initialised in the status
        ),
        "Plant" => (
            MultiScaleModel(
                model=DegreeDaysFTSW(
                    threshold_ftsw_stress=p.parameters[:phyllochron][:threshold_ftsw_stress],
                ),
                mapping=[PreviousTimeStep(:ftsw) => "Soil",],
            ),
            DailyPlantAgeModel(),
            PhyllochronModel(
                p.parameters[:phyllochron][:age_palm_maturity],
                p.parameters[:phyllochron][:production_speed_initial],
                p.parameters[:phyllochron][:production_speed_mature],
            ),
            MultiScaleModel(
                model=PlantLeafAreaModel(),
                mapping=[:leaf_area_leaves => ["Leaf" => :leaf_area], :leaf_states => ["Leaf" => :state],],
            ),
            MultiScaleModel(
                model=PhytomerEmission(p.mtg),
                mapping=[:graph_node_count => "Scene",],
            ),
            MultiScaleModel(
                model=PlantRm(),
                mapping=[:Rm_organs => ["Leaf", "Internode", "Male", "Female"] .=> :Rm],
            ),
            MultiScaleModel(
                model=SceneToPlantLightPartitioning(p.parameters[:scene_area]),
                mapping=[:aPPFD_scene => "Scene" => :aPPFD, :scene_leaf_area => "Scene" => :leaf_area],
            ),
            MultiScaleModel(
                model=RUE_FTSW(p.parameters[:RUE], p.parameters[:threshold_ftsw]),
                mapping=[PreviousTimeStep(:ftsw) => "Soil",],
            ),
            CarbonOfferRm(),
            MultiScaleModel(
                model=OrgansCarbonAllocationModel(p.parameters[:carbon_demand][:reserves][:cost_reserve_mobilization]),
                mapping=[
                    :carbon_demand_organs => ["Leaf", "Internode", "Male", "Female"] .=> :carbon_demand,
                    :carbon_allocation_organs => ["Leaf", "Internode", "Male", "Female"] .=> :carbon_allocation,
                    PreviousTimeStep(:reserve_organs) => ["Leaf", "Internode"] .=> :reserve,
                    PreviousTimeStep(:reserve)
                ],
            ),
            MultiScaleModel(
                model=OrganReserveFilling(),
                mapping=[
                    :potential_reserve_organs => ["Internode", "Leaf"] .=> :potential_reserve,
                    :reserve_organs => ["Internode", "Leaf"] .=> :reserve,
                ],
            ),
            MultiScaleModel(
                model=PlantBunchHarvest(),
                mapping=[
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
                mapping=[:plant_age => "Plant",],
            ),
            # DegreeDaysFTSW(
            #     threshold_ftsw_stress=p.parameters[:phyllochron][:threshold_ftsw_stress],
            # ), #! we should use this one instead of DailyDegreeDaysSinceInit I think
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
            ),
            MultiScaleModel(
                model=SexDetermination(
                    TT_flowering=p.parameters[:inflo][:TT_flowering],
                    duration_abortion=p.parameters[:inflo][:duration_abortion],
                    duration_sex_determination=p.parameters[:inflo][:duration_sex_determination],
                    sex_ratio_min=p.parameters[:inflo][:sex_ratio_min],
                    sex_ratio_ref=p.parameters[:inflo][:sex_ratio_ref],
                    random_seed=p.parameters[:inflo][:random_seed],
                ),
                mapping=[
                    PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm,
                    PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand,
                ],
            ),
            MultiScaleModel(
                model=ReproductiveOrganEmission(p.mtg),
                mapping=[:graph_node_count => "Scene", :phytomer_count => "Plant"],
            ),
            MultiScaleModel(
                model=AbortionRate(
                    TT_flowering=p.parameters[:inflo][:TT_flowering],
                    duration_abortion=p.parameters[:inflo][:duration_abortion],
                    abortion_rate_max=p.parameters[:inflo][:abortion_rate_max],
                    abortion_rate_ref=p.parameters[:inflo][:abortion_rate_ref],
                    random_seed=p.parameters[:inflo][:random_seed],
                ),
                mapping=[
                    PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm,
                    PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand,
                ],
            ),
            MultiScaleModel(
                model=InfloStateModel(
                    TT_flowering=p.parameters[:inflo][:TT_flowering],
                    duration_flowering_male=p.parameters[:male][:duration_flowering_male],
                    duration_fruit_setting=p.parameters[:female][:duration_fruit_setting],
                    TT_harvest=p.parameters[:female][:TT_harvest],
                    fraction_period_oleosynthesis=p.parameters[:female][:fraction_period_oleosynthesis],
                ), # Compute the state of the phytomer
                mapping=[:state_organs => ["Leaf", "Male", "Female"] .=> :state,],
                #! note: the mapping is artificial, we compute the state of those organs in the function directly because we use the status of a phytomer to give it to its children
                #! second note: the models should really be associated to the organs (female and male inflo + leaves)
            )
        ),
        "Internode" =>
            (
                MultiScaleModel(
                    model=InitiationAgeFromPlantAge(),
                    mapping=[:plant_age => "Plant",],
                ),
                MultiScaleModel(
                    model=DailyDegreeDaysSinceInit(),
                    mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
                ),
                MultiScaleModel(
                    model=RmQ10FixedN(
                        p.parameters[:respiration][:Internode][:Q10],
                        p.parameters[:respiration][:Internode][:Mr],
                        p.parameters[:respiration][:Internode][:T_ref],
                        p.parameters[:respiration][:Internode][:P_alive],
                    ),
                    mapping=[PreviousTimeStep(:biomass),],
                ),
                FinalPotentialInternodeDimensionModel(
                    p.parameters[:potential_dimensions][:age_max_height],
                    p.parameters[:potential_dimensions][:age_max_radius],
                    p.parameters[:potential_dimensions][:min_height],
                    p.parameters[:potential_dimensions][:min_radius],
                    p.parameters[:potential_dimensions][:max_height],
                    p.parameters[:potential_dimensions][:max_radius],
                ),
                PotentialInternodeDimensionModel(
                    p.parameters[:potential_dimensions][:inflexion_point_height],
                    p.parameters[:potential_dimensions][:slope_height],
                    p.parameters[:potential_dimensions][:inflexion_point_radius],
                    p.parameters[:potential_dimensions][:slope_radius],
                ),
                InternodeDimensionModel(p.parameters[:carbon_demand][:internode][:stem_apparent_density]),
                InternodeCarbonDemandModel(
                    p.parameters[:carbon_demand][:internode][:stem_apparent_density],
                    p.parameters[:carbon_demand][:internode][:respiration_cost]
                ),
                MultiScaleModel(
                    model=PotentialReserveInternode(
                        p.parameters[:nsc_max]
                    ),
                    mapping=[PreviousTimeStep(:biomass), PreviousTimeStep(:reserve)],
                ),
                InternodeBiomass(
                    initial_biomass=p.parameters[:potential_dimensions][:min_height] * p.parameters[:potential_dimensions][:min_radius] * p.parameters[:carbon_demand][:internode][:stem_apparent_density],
                    respiration_cost=p.parameters[:carbon_demand][:internode][:respiration_cost]
                ),
            ),
        "Leaf" => (
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
            ),
            FinalPotentialAreaModel(
                p.parameters[:potential_area][:age_first_mature_leaf],
                p.parameters[:potential_area][:leaf_area_first_leaf],
                p.parameters[:potential_area][:leaf_area_mature_leaf],
            ),
            PotentialAreaModel(
                p.parameters[:potential_area][:inflexion_index],
                p.parameters[:potential_area][:slope],
            ),
            MultiScaleModel(
                model=LeafStateModel(),
                mapping=[:rank_leaves => ["Leaf" => :rank], :state_phytomers => ["Phytomer" => :state],],
            ),
            MultiScaleModel(
                model=RankLeafPruning(p.parameters[:rank_leaf_pruning]),
                mapping=[:state_phytomers => ["Phytomer" => :state],],
            ),
            MultiScaleModel(
                model=InitiationAgeFromPlantAge(),
                mapping=[:plant_age => "Plant",],
            ),
            MultiScaleModel(
                model=LeafAreaModel(
                    p.parameters[:lma_min],
                    p.parameters[:leaflets_biomass_contribution],
                    p.parameters[:potential_area][:leaf_area_first_leaf],
                ),
                mapping=[PreviousTimeStep(:biomass),],
            ),
            MultiScaleModel(
                model=RmQ10FixedN(
                    p.parameters[:respiration][:Leaf][:Q10],
                    p.parameters[:respiration][:Leaf][:Mr],
                    p.parameters[:respiration][:Leaf][:T_ref],
                    p.parameters[:respiration][:Leaf][:P_alive],
                ),
                mapping=[PreviousTimeStep(:biomass),],
            ),
            LeafCarbonDemandModelPotentialArea(
                p.parameters[:lma_min],
                p.parameters[:carbon_demand][:leaf][:respiration_cost],
                p.parameters[:leaflets_biomass_contribution]
            ),
            MultiScaleModel(
                model=PotentialReserveLeaf(
                    p.parameters[:lma_min],
                    p.parameters[:lma_max],
                    p.parameters[:leaflets_biomass_contribution]
                ),
                mapping=[PreviousTimeStep(:leaf_area), PreviousTimeStep(:reserve)],
            ),
            LeafBiomass(
                initial_biomass=p.parameters[:potential_area][:leaf_area_first_leaf] * p.parameters[:lma_min] /
                                p.parameters[:leaflets_biomass_contribution],
                respiration_cost=p.parameters[:carbon_demand][:leaf][:respiration_cost],
            ),
        ),
        "Male" => (
            MultiScaleModel(
                model=InitiationAgeFromPlantAge(),
                mapping=[:plant_age => "Plant",],
            ),
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
            ),
            MaleFinalPotentialBiomass(
                p.parameters[:male][:male_max_biomass],
                p.parameters[:male][:age_mature_male],
                p.parameters[:male][:fraction_biomass_first_male],
            ),
            MultiScaleModel(
                model=RmQ10FixedN(
                    p.parameters[:respiration][:Male][:Q10],
                    p.parameters[:respiration][:Male][:Mr],
                    p.parameters[:respiration][:Male][:T_ref],
                    p.parameters[:respiration][:Male][:P_alive],
                ),
                mapping=[PreviousTimeStep(:biomass),],
            ),
            MaleCarbonDemandModel(
                p.parameters[:carbon_demand][:male][:respiration_cost],
                p.parameters[:inflo][:TT_flowering],
                p.parameters[:male][:duration_flowering_male],
            ),
            MaleBiomass(
                p.parameters[:carbon_demand][:male][:respiration_cost],
            ),
        ),
        "Female" => (
            MultiScaleModel(
                model=InitiationAgeFromPlantAge(),
                mapping=[:plant_age => "Plant",],
            ),
            MultiScaleModel(
                model=DailyDegreeDaysSinceInit(),
                mapping=[:TEff => "Plant",],
            ),
            MultiScaleModel(
                model=RmQ10FixedN(
                    p.parameters[:respiration][:Female][:Q10],
                    p.parameters[:respiration][:Female][:Mr],
                    p.parameters[:respiration][:Female][:T_ref],
                    p.parameters[:respiration][:Female][:P_alive],
                ),
                mapping=[PreviousTimeStep(:biomass),],
            ),
            FemaleFinalPotentialFruits(
                p.parameters[:female][:days_increase_number_fruits],
                p.parameters[:female][:days_maximum_number_fruits],
                p.parameters[:female][:fraction_first_female],
                p.parameters[:female][:potential_fruit_number_at_maturity],
                p.parameters[:female][:potential_fruit_weight_at_maturity],
                p.parameters[:female][:stalk_max_biomass],
            ),
            MultiScaleModel(
                model=NumberSpikelets(
                    TT_flowering=p.parameters[:inflo][:TT_flowering],
                    duration_dev_spikelets=p.parameters[:female][:duration_dev_spikelets],
                ),
                mapping=[PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm, PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand],
            ),
            MultiScaleModel(
                model=NumberFruits(
                    TT_flowering=p.parameters[:inflo][:TT_flowering],
                    duration_fruit_setting=p.parameters[:female][:duration_fruit_setting],
                ),
                mapping=[PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm, PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand],
            ),
            FemaleCarbonDemandModel(
                p.parameters[:carbon_demand][:female][:respiration_cost],
                p.parameters[:carbon_demand][:female][:respiration_cost_oleosynthesis],
                p.parameters[:inflo][:TT_flowering],
                p.parameters[:female][:TT_harvest],
                p.parameters[:female][:duration_fruit_setting],
                p.parameters[:female][:oil_content],
                p.parameters[:female][:fraction_period_oleosynthesis],
                p.parameters[:female][:fraction_period_stalk],
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
                mapping=[:TEff => "Scene",], # Using TEff computed at scene scale
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
                mapping=[PreviousTimeStep(:biomass),],
            ),
        ),
        "Soil" => (
            # light_interception=Beer{Soil}(),
            MultiScaleModel(
                model=FTSW(
                    ini_root_depth=p.parameters[:soil][:ini_root_depth],
                    H_FC=p.parameters[:soil][:field_capacity],
                    H_WP_Z1=p.parameters[:soil][:wilting_point_1],
                    Z1=p.parameters[:soil][:thickness_1],
                    H_WP_Z2=p.parameters[:soil][:wilting_point_2],
                    Z2=p.parameters[:soil][:thickness_2],
                    H_0=p.parameters[:soil][:initial_water_content],
                    KC=p.parameters[:soil][:Kc],
                    TRESH_EVAP=p.parameters[:soil][:evaporation_threshold],
                    TRESH_FTSW_TRANSPI=p.parameters[:soil][:transpiration_threshold],
                ),
                mapping=[:ET0 => "Scene", :aPPFD => "Scene"], # Using TEff computed at scene scale
            ),
            #! Root growth should be in the roots part, but it is a hard-coupled model with 
            #! the FSTW, so we need it here for now.
            MultiScaleModel(
                model=RootGrowthFTSW(ini_root_depth=p.parameters[:soil][:ini_root_depth]),
                mapping=[:TEff => "Scene",], # Using TEff computed at scene scale
            ),
        )
    )
end

