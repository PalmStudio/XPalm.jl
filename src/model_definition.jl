function _xpalm_application(
    scale::Symbol,
    model;
    name=PlantSimEngine.process(model),
    inputs=NamedTuple(),
    calls=NamedTuple(),
    outputs_to=NamedTuple(),
    output_routing=NamedTuple(),
    updates=(),
)
    return PlantSimEngine.ModelSpec(
        model;
        name=Symbol(scale, "__", name),
        on=PlantSimEngine.Many(scale=scale),
        inputs=inputs,
        calls=calls,
        outputs_to=outputs_to,
        output_routing=output_routing,
        updates=updates,
    )
end

function _phytomer_emission_application(mtg)
    return _xpalm_application(
        :Plant, PhytomerEmission(mtg);
        inputs=(:graph_node_count => PlantSimEngine.One(
            scale=:Scene,
            within=PlantSimEngine.SceneScope(),
            var=:graph_node_count,
        ),
        :plant_age => PlantSimEngine.One(
            within=PlantSimEngine.Self(),
            application=:Plant__plant_age,
            var=:plant_age,
        ),
        :emit_phytomer => PlantSimEngine.One(
            within=PlantSimEngine.Self(),
            application=:Plant__phyllochron,
            var=:emit_phytomer,
        ),),
        calls=(:phytomer_initiation_age => PlantSimEngine.Many(
            scale=:Phytomer,
            within=PlantSimEngine.SelfPlant(),
            application=:Phytomer__initiation_age,
        ),
        :internode_initiation_age => PlantSimEngine.Many(
            scale=:Internode,
            within=PlantSimEngine.SelfPlant(),
            application=:Internode__initiation_age,
        ),
        :internode_final_potential_dimensions => PlantSimEngine.Many(
            scale=:Internode,
            within=PlantSimEngine.SelfPlant(),
            application=:Internode__internode_final_potential_dimensions,
        ),
        :internode_initial_maintenance_respiration => PlantSimEngine.Initializer(
            PlantSimEngine.One(
                scale=:Internode,
                within=PlantSimEngine.SelfPlant(),
                application=:Internode__maintenance_respiration,
            ),
        ),
        :leaf_initiation_age => PlantSimEngine.Many(
            scale=:Leaf,
            within=PlantSimEngine.SelfPlant(),
            application=:Leaf__initiation_age,
        ),
        :leaf_final_potential_area => PlantSimEngine.Many(
            scale=:Leaf,
            within=PlantSimEngine.SelfPlant(),
            application=:Leaf__leaf_final_potential_area,
        ),
        :leaf_initial_maintenance_respiration => PlantSimEngine.Initializer(
            PlantSimEngine.One(
                scale=:Leaf,
                within=PlantSimEngine.SelfPlant(),
                application=:Leaf__maintenance_respiration,
            ),
        ),),
    )
end

function _reproductive_organ_emission_application(mtg)
    return _xpalm_application(
        :Phytomer,
        ReproductiveOrganEmission(mtg);
        inputs=(:graph_node_count => PlantSimEngine.One(
            scale=:Scene,
            within=PlantSimEngine.SceneScope(),
            var=:graph_node_count,
        ),
        :phytomer_count => PlantSimEngine.One(
            scale=:Plant,
            within=PlantSimEngine.SelfPlant(),
            application=:Plant__phytomer_emission,
            var=:phytomer_count,
        ),
        :plant_age => PlantSimEngine.One(
            scale=:Plant,
            within=PlantSimEngine.SelfPlant(),
            application=:Plant__plant_age,
            var=:plant_age,
        ),
        :sex => PlantSimEngine.One(
            within=PlantSimEngine.Self(),
            application=:Phytomer__sex_determination,
            var=:sex,
        ),
        :state => PlantSimEngine.One(
            within=PlantSimEngine.Self(),
            var=:state,
            from_status=true,
        ),
        :emit_reproductive_organ => PlantSimEngine.One(
            within=PlantSimEngine.Self(),
            application=:Phytomer__sex_determination,
            var=:emit_reproductive_organ,
        ),),
        calls=(:male_initiation_age => PlantSimEngine.Many(
            scale=:Male,
            within=PlantSimEngine.Subtree(),
            application=:Male__initiation_age,
        ),
        :male_final_potential_biomass => PlantSimEngine.Many(
            scale=:Male,
            within=PlantSimEngine.Subtree(),
            application=:Male__final_potential_biomass,
        ),
        :male_initial_maintenance_respiration => PlantSimEngine.Initializer(
            PlantSimEngine.One(
                scale=:Male,
                within=PlantSimEngine.Subtree(),
                application=:Male__maintenance_respiration,
            ),
        ),
        :female_initiation_age => PlantSimEngine.Many(
            scale=:Female,
            within=PlantSimEngine.Subtree(),
            application=:Female__initiation_age,
        ),
        :female_final_potential_biomass => PlantSimEngine.Many(
            scale=:Female,
            within=PlantSimEngine.Subtree(),
            application=:Female__final_potential_biomass,
        ),
        :female_initial_maintenance_respiration => PlantSimEngine.Initializer(
            PlantSimEngine.One(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__maintenance_respiration,
            ),
        ),),
    )
end

"""
    model_applications(p; architecture=false)

Define the model applications used by XPalm.

Applications are listed in their intended daily execution order. Each entry
shows the model, the scale where it runs, and any cross-scale inputs or hard
calls. PlantSimEngine may add dependency-order edges, but otherwise preserves
this order.

# Arguments

- `p`: a [`Palm`](@ref) containing the MTG and model parameters.
- `architecture`: also compute the 3D palm architecture when `true`.

# Returns

A tuple of `PlantSimEngine.ModelSpec` applications.
"""
function model_applications(p; architecture=false)
    parameters = p.parameters

    # Scene drivers and canopy aggregation.
    scene_applications = (
        _xpalm_application(
            :Scene,
            ET0_BP(
                parameters["plot"]["latitude"],
                parameters["plot"]["altitude"],
            ),
        ),
        _xpalm_application(:Scene, DailyDegreeDays()),
        _xpalm_application(
            :Scene,
            LAIModel(parameters["plot"]["scene_area"]);
            inputs=(:leaf_areas => PlantSimEngine.Many(
                scale=:Plant,
                within=PlantSimEngine.SceneScope(),
                application=:Plant__leaf_area,
                var=:leaf_area,
            ),),
        ),
        _xpalm_application(
            :Scene,
            Beer(k=parameters["radiation"]["k"]),
        ),
        _xpalm_application(:Scene, GraphNodeCount(length(p.mtg))),
    )

    plant_thermal_time_application =
        _xpalm_application(:Plant, DailyDegreeDays())

    # Thermal time and maintenance respiration run before organ creation.
    # Existing organs use previous-step biomass. The same scheduled respiration
    # applications are initializer targets for organs created during this step.
    early_organ_applications = (
        _xpalm_application(
            :Phytomer,
            DailyDegreeDaysSinceInit();
            inputs=(:TEff => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__thermal_time,
                var=:TEff,
            ),),
        ),
        _xpalm_application(
            :Internode,
            DailyDegreeDaysSinceInit();
            inputs=(:TEff => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__thermal_time,
                var=:TEff,
            ),),
        ),
        _xpalm_application(
            :Leaf,
            DailyDegreeDaysSinceInit();
            inputs=(:TEff => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__thermal_time,
                var=:TEff,
            ),),
        ),
        _xpalm_application(
            :Male,
            DailyDegreeDaysSinceInit();
            inputs=(:TEff => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__thermal_time,
                var=:TEff,
            ),),
        ),
        _xpalm_application(
            :Female,
            DailyDegreeDaysSinceInit();
            inputs=(:TEff => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__thermal_time,
                var=:TEff,
            ),),
        ),
        _xpalm_application(
            :Internode,
            RmQ10FixedN(
                parameters["respiration"]["Internode"]["Q10"],
                parameters["respiration"]["Internode"]["Mr"],
                parameters["respiration"]["Internode"]["T_ref"],
                parameters["respiration"]["Internode"]["P_alive"],
            );
            inputs=(PreviousTimeStep(:biomass) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Internode__biomass,
                var=:biomass,
            ),),
        ),
        _xpalm_application(
            :Leaf,
            RmQ10FixedN(
                parameters["respiration"]["Leaf"]["Q10"],
                parameters["respiration"]["Leaf"]["Mr"],
                parameters["respiration"]["Leaf"]["T_ref"],
                parameters["respiration"]["Leaf"]["P_alive"],
            );
            inputs=(PreviousTimeStep(:biomass) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Leaf__leaf_pruning,
                var=:biomass,
            ),),
        ),
        _xpalm_application(
            :Male,
            RmQ10FixedN(
                parameters["respiration"]["Male"]["Q10"],
                parameters["respiration"]["Male"]["Mr"],
                parameters["respiration"]["Male"]["T_ref"],
                parameters["respiration"]["Male"]["P_alive"],
            );
            inputs=(PreviousTimeStep(:biomass) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Male__biomass,
                var=:biomass,
            ),),
        ),
        _xpalm_application(
            :Female,
            RmQ10FixedN(
                parameters["respiration"]["Female"]["Q10"],
                parameters["respiration"]["Female"]["Mr"],
                parameters["respiration"]["Female"]["T_ref"],
                parameters["respiration"]["Female"]["P_alive"],
            );
            inputs=(PreviousTimeStep(:biomass) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Female__harvest,
                var=:biomass,
            ),),
        ),
    )

    plant_applications = (
        _xpalm_application(:Plant, DailyPlantAgeModel()),
        _xpalm_application(
            :Plant,
            PhyllochronModel(
                parameters["phyllochron"]["age_palm_maturity"],
                parameters["phyllochron"]["production_speed_initial"],
                parameters["phyllochron"]["production_speed_mature"],
            ),
        ),
        _phytomer_emission_application(p.mtg),
        _xpalm_application(
            :Plant, PlantLeafAreaModel();
            inputs=(:leaf_area_leaves => PlantSimEngine.Many(
                scale=:Leaf,
                within=PlantSimEngine.Subtree(),
                application=:Leaf__leaf_area,
                var=:leaf_area,
            ),
            :leaf_states => PlantSimEngine.Many(
                scale=:Leaf,
                within=PlantSimEngine.Subtree(),
                application=:Leaf__state,
                var=:state,
            ),),
        ),
        _xpalm_application(
            :Plant, PlantRm();
            inputs=(:Rm_organs => PlantSimEngine.Many(
                scale=(:Leaf, :Internode, :Male, :Female),
                within=PlantSimEngine.Subtree(),
                process=:maintenance_respiration,
                var=:Rm,
            ),),
        ),
        _xpalm_application(
            :Plant,
            SceneToPlantLightPartitioning(parameters["plot"]["scene_area"]);
            inputs=(:aPPFD_scene => PlantSimEngine.One(
                scale=:Scene,
                within=PlantSimEngine.SceneScope(),
                var=:aPPFD,
            ),
            :scene_leaf_area => PlantSimEngine.One(
                scale=:Scene,
                within=PlantSimEngine.SceneScope(),
                var=:leaf_area,
            ),),
        ),
        _xpalm_application(
            :Plant,
            RUE_FTSW(
                parameters["radiation"]["RUE"],
                parameters["radiation"]["threshold_ftsw"],
            );
            inputs=(PreviousTimeStep(:ftsw) => PlantSimEngine.One(
                scale=:Soil,
                within=PlantSimEngine.SceneScope(),
                var=:ftsw,
            ),),
        ),
        _xpalm_application(:Plant, CarbonOfferRm()),
        _xpalm_application(
            :Plant,
            OrgansCarbonAllocationModel(
                parameters["carbon_demand"]["reserves"]["cost_reserve_mobilization"],
            );
            inputs=(:carbon_demand_organs => PlantSimEngine.Many(
                scale=(:Leaf, :Internode, :Male, :Female),
                within=PlantSimEngine.Subtree(),
                var=:carbon_demand,
            ),
            PreviousTimeStep(:previous_reserve_organs) => PlantSimEngine.Many(
                scale=(:Internode, :Leaf),
                within=PlantSimEngine.Subtree(),
                var=:reserve,
            ),),
            outputs_to=(
                carbon_allocation=PlantSimEngine.OutputTo(
                    PlantSimEngine.Many(
                        scale=(:Leaf, :Internode, :Male, :Female),
                        within=PlantSimEngine.Subtree(),
                    );
                    vars=(carbon_allocation=PlantSimEngine.Default(0.0),),
                ),
                reserve=PlantSimEngine.OutputTo(
                    PlantSimEngine.Many(
                        scale=(:Internode, :Leaf),
                        within=PlantSimEngine.Subtree(),
                    );
                    vars=(reserve=PlantSimEngine.Default(0.0),),
                ),
            ),
        ),
        _xpalm_application(
            :Plant, OrganReserveFilling();
            inputs=(:potential_reserve_organs => PlantSimEngine.Many(
                scale=(:Internode, :Leaf),
                within=PlantSimEngine.Subtree(),
                var=:potential_reserve,
            ),
            :reserve_organs => PlantSimEngine.Many(
                scale=(:Internode, :Leaf),
                within=PlantSimEngine.Subtree(),
                application=:Plant__carbon_allocation,
                var=:reserve,
            ),),
            outputs_to=(reserve=PlantSimEngine.OutputTo(
                PlantSimEngine.Many(
                    scale=(:Internode, :Leaf),
                    within=PlantSimEngine.Subtree(),
                );
                vars=(reserve=PlantSimEngine.Default(0.0),),
            ),),
            updates=PlantSimEngine.Updates(
                :reserve;
                after=:Plant__carbon_allocation,
            ),
        ),
        _xpalm_application(
            :Plant, PlantBunchHarvest();
            inputs=(:biomass_bunch_harvested_organs => PlantSimEngine.Many(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__harvest,
                var=:biomass_bunch_harvested,
            ),
            :biomass_stalk_harvested_organs => PlantSimEngine.Many(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__harvest,
                var=:biomass_stalk_harvested,
            ),
            :biomass_fruit_harvested_organs => PlantSimEngine.Many(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__harvest,
                var=:biomass_fruit_harvested,
            ),
            :biomass_bunch_harvested_cum_organs => PlantSimEngine.Many(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__harvest,
                var=:biomass_bunch_harvested_cum,
            ),
            :biomass_oil_harvested_organs => PlantSimEngine.Many(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__harvest,
                var=:biomass_oil_harvested,
            ),
            :biomass_oil_harvested_cum_organs => PlantSimEngine.Many(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__harvest,
                var=:biomass_oil_harvested_cum,
            ),
            :biomass_oil_harvested_potential_organs => PlantSimEngine.Many(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__harvest,
                var=:biomass_oil_harvested_potential,
            ),
            :biomass_oil_harvested_potential_cum_organs => PlantSimEngine.Many(
                scale=:Female,
                within=PlantSimEngine.Subtree(),
                application=:Female__harvest,
                var=:biomass_oil_harvested_potential_cum,
            ),),
        ),
    )

    phytomer_applications = (
        _xpalm_application(
            :Phytomer,
            InitiationAgeFromPlantAge();
            inputs=(:plant_age => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__plant_age,
                var=:plant_age,
            ),),
        ),
        _xpalm_application(
            :Phytomer,
            SexDetermination(
                TT_flowering=parameters["phenology"]["inflorescence"]["TT_flowering"],
                duration_abortion=parameters["phenology"]["inflorescence"]["duration_abortion"],
                duration_sex_determination=parameters["phenology"]["inflorescence"]["duration_sex_determination"],
                sex_ratio_min=parameters["reproduction"]["sex_ratio"]["sex_ratio_min"],
                sex_ratio_ref=parameters["reproduction"]["sex_ratio"]["sex_ratio_ref"],
                random_seed=parameters["reproduction"]["sex_ratio"]["random_seed"],
            );
            inputs=(PreviousTimeStep(:carbon_offer_plant) => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__carbon_offer,
                var=:carbon_offer_after_rm,
            ),
            PreviousTimeStep(:carbon_demand_plant) => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__carbon_allocation,
                var=:carbon_demand,
            ),
            :state => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                var=:state,
                from_status=true,
            ),),
        ),
        _reproductive_organ_emission_application(p.mtg),
        _xpalm_application(
            :Phytomer,
            AbortionRate(
                TT_flowering=parameters["phenology"]["inflorescence"]["TT_flowering"],
                duration_abortion=parameters["phenology"]["inflorescence"]["duration_abortion"],
                abortion_rate_max=parameters["reproduction"]["abortion"]["abortion_rate_max"],
                abortion_rate_ref=parameters["reproduction"]["abortion"]["abortion_rate_ref"],
                random_seed=parameters["reproduction"]["abortion"]["random_seed"],
            );
            inputs=(PreviousTimeStep(:carbon_offer_plant) => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__carbon_offer,
                var=:carbon_offer_after_rm,
            ),
            PreviousTimeStep(:carbon_demand_plant) => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__carbon_allocation,
                var=:carbon_demand,
            ),),
        ),
        _xpalm_application(
            :Phytomer,
            InfloStateModel(
                TT_flowering=parameters["phenology"]["inflorescence"]["TT_flowering"],
                duration_flowering_male=parameters["phenology"]["Male"]["duration_flowering_male"],
                duration_fruit_setting=parameters["phenology"]["Female"]["duration_fruit_setting"],
                duration_bunch_development=parameters["phenology"]["Female"]["duration_bunch_development"],
                fraction_period_oleosynthesis=parameters["phenology"]["Female"]["fraction_period_oleosynthesis"],
            ),
        ),
    )

    internode_applications = (
        _xpalm_application(
            :Internode,
            InitiationAgeFromPlantAge();
            inputs=(:plant_age => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__plant_age,
                var=:plant_age,
            ),),
        ),
        _xpalm_application(
            :Internode,
            FinalPotentialInternodeDimensionModel(
                parameters["dimensions"]["internode"]["age_max_height"],
                parameters["dimensions"]["internode"]["age_max_radius"],
                parameters["dimensions"]["internode"]["min_height"],
                parameters["dimensions"]["internode"]["min_radius"],
                parameters["dimensions"]["internode"]["max_height"],
                parameters["dimensions"]["internode"]["max_radius"],
            ),
        ),
        _xpalm_application(
            :Internode,
            PotentialInternodeDimensionModel(
                inflexion_point_height=parameters["dimensions"]["internode"]["inflexion_point_height"],
                slope_height=parameters["dimensions"]["internode"]["slope_height"],
                inflexion_point_radius=parameters["dimensions"]["internode"]["inflexion_point_radius"],
                slope_radius=parameters["dimensions"]["internode"]["slope_radius"],
            ),
        ),
        _xpalm_application(
            :Internode,
            InternodeDimensionModel(
                parameters["carbon_demand"]["internode"]["apparent_density"],
            ),
        ),
        _xpalm_application(
            :Internode,
            InternodeCarbonDemandModel(
                apparent_density=parameters["carbon_demand"]["internode"]["apparent_density"],
                carbon_concentration=parameters["carbon_demand"]["internode"]["carbon_concentration"],
                respiration_cost=parameters["carbon_demand"]["internode"]["respiration_cost"],
            ),
        ),
        _xpalm_application(
            :Internode,
            PotentialReserveInternode(parameters["reserves"]["nsc_max"]);
            inputs=(PreviousTimeStep(:biomass) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Internode__biomass,
                var=:biomass,
            ),
            PreviousTimeStep(:reserve) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                var=:reserve,
            ),),
        ),
        _xpalm_application(
            :Internode,
            InternodeBiomass(
                initial_biomass=parameters["dimensions"]["internode"]["min_height"] *
                                parameters["dimensions"]["internode"]["min_radius"] *
                                parameters["carbon_demand"]["internode"]["apparent_density"],
                respiration_cost=parameters["carbon_demand"]["internode"]["respiration_cost"],
            );
            inputs=(:carbon_allocation => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                var=:carbon_allocation,
            ),),
        ),
    )

    leaf_applications = (
        _xpalm_application(
            :Leaf,
            InitiationAgeFromPlantAge();
            inputs=(:plant_age => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__plant_age,
                var=:plant_age,
            ),),
        ),
        _xpalm_application(
            :Leaf,
            FinalPotentialAreaModel(
                parameters["dimensions"]["leaf"]["age_first_mature_leaf"],
                parameters["dimensions"]["leaf"]["leaf_area_first_leaf"],
                parameters["dimensions"]["leaf"]["leaf_area_mature_leaf"],
            ),
        ),
        _xpalm_application(
            :Leaf,
            PotentialAreaModel(
                parameters["dimensions"]["leaf"]["inflexion_index"],
                parameters["dimensions"]["leaf"]["slope"],
            ),
        ),
        _xpalm_application(
            :Leaf, LeafStateModel();
            inputs=(:rank_leaves => PlantSimEngine.Many(
                scale=:Leaf,
                within=PlantSimEngine.SelfPlant(),
                var=:rank,
            ),
            :state_phytomers => PlantSimEngine.Many(
                scale=:Phytomer,
                within=PlantSimEngine.SelfPlant(),
                application=:Phytomer__state,
                var=:state,
            ),),
        ),
        _xpalm_application(
            :Leaf,
            LeafAreaModel(
                parameters["mass_and_dimensions"]["leaf"]["lma_min"],
                parameters["biomass"]["leaf"]["leaflets_biomass_contribution"],
                parameters["dimensions"]["leaf"]["leaf_area_first_leaf"],
                parameters["biomass"]["leaf"]["carbon_concentration"],
            );
            inputs=(PreviousTimeStep(:biomass) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Leaf__leaf_pruning,
                var=:biomass,
            ),),
        ),
        _xpalm_application(
            :Leaf,
            LeafCarbonDemandModelPotentialArea(
                parameters["mass_and_dimensions"]["leaf"]["lma_min"],
                parameters["carbon_demand"]["leaf"]["respiration_cost"],
                parameters["biomass"]["leaf"]["leaflets_biomass_contribution"],
                parameters["biomass"]["leaf"]["carbon_concentration"],
            );
            inputs=(:state => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Leaf__state,
                var=:state,
            ),),
        ),
        _xpalm_application(
            :Leaf,
            PotentialReserveLeaf(
                parameters["mass_and_dimensions"]["leaf"]["lma_min"],
                parameters["mass_and_dimensions"]["leaf"]["lma_max"],
                parameters["biomass"]["leaf"]["leaflets_biomass_contribution"],
                parameters["biomass"]["leaf"]["carbon_concentration"],
            );
            inputs=(PreviousTimeStep(:leaf_area) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Leaf__leaf_pruning,
                var=:leaf_area,
            ),
            PreviousTimeStep(:reserve) => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Leaf__leaf_pruning,
                var=:reserve,
            ),),
        ),
        _xpalm_application(
            :Leaf,
            LeafBiomass(
                # Leaf area represents leaflets only. Convert their area to
                # total leaf dry mass, then to total leaf carbon biomass (gC).
                initial_biomass=parameters["dimensions"]["leaf"]["leaf_area_first_leaf"] *
                                parameters["mass_and_dimensions"]["leaf"]["lma_min"] /
                                parameters["biomass"]["leaf"]["leaflets_biomass_contribution"] *
                                parameters["biomass"]["leaf"]["carbon_concentration"],
                respiration_cost=parameters["carbon_demand"]["leaf"]["respiration_cost"],
                leaflets_biomass_contribution=parameters["biomass"]["leaf"]["leaflets_biomass_contribution"],
                rachis_biomass_contribution=parameters["biomass"]["leaf"]["rachis_biomass_contribution"],
                petiole_biomass_contribution=parameters["biomass"]["leaf"]["petiole_biomass_contribution"],
            );
            inputs=(:carbon_allocation => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                var=:carbon_allocation,
            ),),
        ),
        _xpalm_application(
            :Leaf,
            RankLeafPruning(parameters["management"]["rank_leaf_pruning"]);
            inputs=(:reserve => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Plant__reserve_filling,
                var=:reserve,
            ),
            :state_phytomers => PlantSimEngine.Many(
                scale=:Phytomer,
                within=PlantSimEngine.SelfPlant(),
                application=:Phytomer__state,
                var=:state,
            ),),
            updates=(PlantSimEngine.Updates(
                :biomass,
                :biomass_leaflets,
                :biomass_rachis,
                :biomass_petiole;
                after=:Leaf__biomass,
            ), PlantSimEngine.Updates(:leaf_area;
            after=:Leaf__leaf_area,), PlantSimEngine.Updates(:state;
            after=:Leaf__state,), PlantSimEngine.Updates(:reserve;
            after=:Plant__reserve_filling,),),
        ),
    )

    male_applications = (
        _xpalm_application(
            :Male,
            InitiationAgeFromPlantAge();
            inputs=(:plant_age => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__plant_age,
                var=:plant_age,
            ),),
        ),
        _xpalm_application(
            :Male,
            MaleFinalPotentialBiomass(
                parameters["biomass"]["Male"]["max_biomass"],
                parameters["phenology"]["Male"]["age_mature_male"],
                parameters["biomass"]["Male"]["fraction_biomass_first_male"],
            ),
        ),
        _xpalm_application(
            :Male,
            MaleCarbonDemandModel(
                respiration_cost=parameters["carbon_demand"]["Male"]["respiration_cost"],
                duration_flowering_male=parameters["phenology"]["Male"]["duration_flowering_male"],
            );
            inputs=(:state => PlantSimEngine.One(
                scale=:Phytomer,
                within=PlantSimEngine.Ancestor(scale=:Phytomer),
                application=:Phytomer__state,
                var=:state,
            ),
            :TEff => PlantSimEngine.One(
                scale=:Scene,
                within=PlantSimEngine.SceneScope(),
                application=:Scene__thermal_time,
                var=:TEff,
            ),),
        ),
        _xpalm_application(
            :Male,
            MaleBiomass(
                parameters["carbon_demand"]["Male"]["respiration_cost"],
            );
            inputs=(:carbon_allocation => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                var=:carbon_allocation,
            ),
            :state => PlantSimEngine.One(
                scale=:Phytomer,
                within=PlantSimEngine.Ancestor(scale=:Phytomer),
                application=:Phytomer__state,
                var=:state,
            ),),
        ),
    )

    female_applications = (
        _xpalm_application(
            :Female,
            InitiationAgeFromPlantAge();
            inputs=(:plant_age => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__plant_age,
                var=:plant_age,
            ),),
        ),
        _xpalm_application(
            :Female,
            FemaleFinalPotentialFruits(
                days_increase_number_fruits=parameters["phenology"]["Female"]["days_increase_number_fruits"],
                days_maximum_number_fruits=parameters["phenology"]["Female"]["days_maximum_number_fruits"],
                fraction_first_female=parameters["reproduction"]["yield_formation"]["fraction_first_female"],
                potential_fruit_number_at_maturity=parameters["reproduction"]["yield_formation"]["potential_fruit_number_at_maturity"],
                potential_fruit_weight_at_maturity=parameters["reproduction"]["yield_formation"]["potential_fruit_weight_at_maturity"],
                stalk_max_biomass=parameters["reproduction"]["yield_formation"]["stalk_max_biomass"],
                oil_content=parameters["reproduction"]["yield_formation"]["oil_content"],
            ),
        ),
        _xpalm_application(
            :Female,
            NumberSpikelets(
                TT_flowering=parameters["phenology"]["inflorescence"]["TT_flowering"],
                duration_dev_spikelets=parameters["phenology"]["Female"]["duration_dev_spikelets"],
            );
            inputs=(PreviousTimeStep(:carbon_offer_plant) => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__carbon_offer,
                var=:carbon_offer_after_rm,
            ),
            PreviousTimeStep(:carbon_demand_plant) => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__carbon_allocation,
                var=:carbon_demand,
            ),),
        ),
        _xpalm_application(
            :Female,
            NumberFruits(
                TT_flowering=parameters["phenology"]["inflorescence"]["TT_flowering"],
                duration_fruit_setting=parameters["phenology"]["Female"]["duration_fruit_setting"],
            );
            inputs=(PreviousTimeStep(:carbon_offer_plant) => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__carbon_offer,
                var=:carbon_offer_after_rm,
            ),
            PreviousTimeStep(:carbon_demand_plant) => PlantSimEngine.One(
                scale=:Plant,
                within=PlantSimEngine.SelfPlant(),
                application=:Plant__carbon_allocation,
                var=:carbon_demand,
            ),),
        ),
        _xpalm_application(
            :Female,
            FemaleCarbonDemandModel(
                respiration_cost=parameters["carbon_demand"]["Female"]["respiration_cost"],
                respiration_cost_oleosynthesis=parameters["carbon_demand"]["Female"]["respiration_cost_oleosynthesis"],
                TT_flowering=parameters["phenology"]["inflorescence"]["TT_flowering"],
                duration_bunch_development=parameters["phenology"]["Female"]["duration_bunch_development"],
                duration_fruit_setting=parameters["phenology"]["Female"]["duration_fruit_setting"],
                fraction_period_oleosynthesis=parameters["phenology"]["Female"]["fraction_period_oleosynthesis"],
                fraction_period_stalk=parameters["phenology"]["Female"]["fraction_period_stalk"],
            );
            inputs=(:state => PlantSimEngine.One(
                scale=:Phytomer,
                within=PlantSimEngine.Ancestor(scale=:Phytomer),
                application=:Phytomer__state,
                var=:state,
            ),
            :fruits_number => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                application=:Female__number_fruits,
                var=:fruits_number,
            ),),
        ),
        _xpalm_application(
            :Female,
            FemaleBiomass(
                parameters["carbon_demand"]["Female"]["respiration_cost"],
                parameters["carbon_demand"]["Female"]["respiration_cost_oleosynthesis"],
            );
            inputs=(:carbon_allocation => PlantSimEngine.One(
                within=PlantSimEngine.Self(),
                var=:carbon_allocation,
            ),
            :state => PlantSimEngine.One(
                scale=:Phytomer,
                within=PlantSimEngine.Ancestor(scale=:Phytomer),
                application=:Phytomer__state,
                var=:state,
            ),),
        ),
        _xpalm_application(
            :Female, BunchHarvest();
            inputs=(:state => PlantSimEngine.One(
                scale=:Phytomer,
                within=PlantSimEngine.Ancestor(scale=:Phytomer),
                application=:Phytomer__state,
                var=:state,
            ),),
            updates=(PlantSimEngine.Updates(:biomass,
            :biomass_stalk,
            :biomass_fruits,
            :biomass_oil,
            :biomass_non_oil;
            after=:Female__biomass,), PlantSimEngine.Updates(:fruits_number;
            after=:Female__number_fruits,),),
        ),
    )

    root_and_soil_applications = (
        _xpalm_application(
            :RootSystem,
            DailyDegreeDaysSinceInit();
            inputs=(:TEff => PlantSimEngine.One(
                scale=:Scene,
                within=PlantSimEngine.SceneScope(),
                application=:Scene__thermal_time,
                var=:TEff,
            ),),
        ),
        _xpalm_application(
            :Soil,
            FTSW_BP(
                ini_root_depth=parameters["water"]["ini_root_depth"],
                H_FC=parameters["water"]["field_capacity"],
                H_WP_Z1=parameters["water"]["wilting_point_1"],
                Z1=parameters["water"]["thickness_1"],
                H_WP_Z2=parameters["water"]["wilting_point_2"],
                Z2=parameters["water"]["thickness_2"],
                H_0=parameters["water"]["initial_water_content"],
                KC=parameters["water"]["Kc"],
                TRESH_EVAP=parameters["water"]["evaporation_threshold"],
                TRESH_FTSW_TRANSPI=parameters["water"]["transpiration_threshold"],
            );
            inputs=(:ET0 => PlantSimEngine.One(
                scale=:Scene,
                within=PlantSimEngine.SceneScope(),
                var=:ET0,
            ),
            :aPPFD => PlantSimEngine.One(
                scale=:Scene,
                within=PlantSimEngine.SceneScope(),
                var=:aPPFD,
            ),),
        ),
        _xpalm_application(
            :Soil,
            RootGrowthFTSW(
                ini_root_depth=parameters["water"]["ini_root_depth"],
            );
            inputs=(:TEff => PlantSimEngine.One(
                scale=:Scene,
                within=PlantSimEngine.SceneScope(),
                application=:Scene__thermal_time,
                var=:TEff,
            ),),
        ),
    )

    applications = (
        scene_applications...,
        plant_thermal_time_application,
        early_organ_applications...,
        plant_applications...,
        phytomer_applications...,
        internode_applications...,
        leaf_applications...,
        male_applications...,
        female_applications...,
        root_and_soil_applications...,
    )

    architecture || return applications

    vpalm = load_vpalm!()
    architecture_application = _xpalm_application(
        :Internode,
        vpalm.GeometryModel(
            mtg=p.mtg,
            rng=Random.MersenneTwister(parameters["vpalm"]["seed"]),
            vpalm_parameters=parameters["vpalm"],
        );
        inputs=(:graph_node_count => PlantSimEngine.One(
            scale=:Scene,
            within=PlantSimEngine.SceneScope(),
            var=:graph_node_count,
        ),
        :is_pruned => PlantSimEngine.One(
            scale=:Leaf,
            relation=:children,
            application=:Leaf__leaf_pruning,
            var=:is_pruned,
        ),
        :height_internodes => PlantSimEngine.One(
            within=PlantSimEngine.Self(),
            var=:height,
        ),
        :radius_internodes => PlantSimEngine.One(
            within=PlantSimEngine.Self(),
            var=:radius,
        ),
        :biomass_leaves => PlantSimEngine.One(
            scale=:Leaf,
            relation=:children,
            var=:biomass,
        ),
        :rank_leaves => PlantSimEngine.One(
            scale=:Leaf,
            relation=:children,
            var=:rank,
        ),),
    )

    return (applications..., architecture_application)
end
