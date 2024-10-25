# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
using CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using Dates
using XPalm

# meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
meteo_raw = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/Meteo_Nigeria_PR.txt"), DataFrame)

meteo = select(
    meteo_raw,
    :ObservationDate => :date,
    :ObservationDate => (x -> Day(1)) => :duration,
    :TAverage => (x -> replace(x, missing => mean(skipmissing(x)))) => :T,
    :TMax => (x -> replace(x, missing => mean(skipmissing(x)))) => :Tmax,
    :TMin => (x -> replace(x, missing => mean(skipmissing(x)))) => :Tmin,
    :Rg => (x -> replace(x, missing => mean(skipmissing(x))) .* 0.48) => :Rg,
    :Rg => (x -> replace(x, missing => mean(skipmissing(x))) .* 0.48) => :Ri_PAR_f,
    :HRMin => (x -> replace(x, missing => mean(skipmissing(x)))) => :Rh_min,
    :HRMax => (x -> replace(x, missing => mean(skipmissing(x)))) => :Rh_max,
    :Rainfall => (x -> replace(x, missing => mean(skipmissing(x)))) => :Precipitations,
    :WindSpeed => (x -> replace(x, missing => mean(skipmissing(x)))) => :Wind,
)
meteo.Rh .= (meteo.Rh_max .- meteo.Rh_min) ./ 2 ./ 100

m = Weather(meteo)

p = XPalm.Palm()

mapping = Dict(
    "Scene" => (
        XPalm.ET0_BP(),
        XPalm.DailyDegreeDays(),
        MultiScaleModel(
            model=XPalm.LAIModel(p.parameters[:scene_area]),
            mapping=[:leaf_area => ["Leaf"],],
        ),
        XPalm.Beer(k=p.parameters[:k]),
        XPalm.GraphNodeCount(length(p.mtg)), # to have the `graph_node_count` variable initialised in the status
    ),
    "Plant" => (
        MultiScaleModel(
            model=XPalm.DegreeDaysFTSW(
                threshold_ftsw_stress=p.parameters[:phyllochron][:threshold_ftsw_stress],
            ),
            mapping=[:ftsw => "Soil",],
        ),
        XPalm.DailyPlantAgeModel(),
        XPalm.PhyllochronModel(
            p.parameters[:phyllochron][:age_palm_maturity],
            p.parameters[:phyllochron][:threshold_ftsw_stress],
            p.parameters[:phyllochron][:production_speed_initial],
            p.parameters[:phyllochron][:production_speed_mature],
        ),
        MultiScaleModel(
            model=XPalm.PlantLeafAreaModel(),
            mapping=[:leaf_area => ["Leaf"],],
        ),
        MultiScaleModel(
            model=XPalm.PhytomerEmission(p.mtg),
            mapping=[:graph_node_count => "Scene",],
        ),
        # XPalm.PhytomerCount(length(p.mtg)), #! maybe finish this ? It was to avoid putting the value inside the MTG nodes (same for graph_node_count -> GraphNodeCount), see add_phytomer
        MultiScaleModel(
            model=XPalm.PlantRm(),
            mapping=[:Rm_organs => ["Leaf", "Internode", "Male", "Female"] .=> :Rm],
        ),
        MultiScaleModel(
            model=XPalm.SceneToPlantLightPartitioning(),
            mapping=[:aPPFD_scene => "Scene" => :aPPFD, :scene_leaf_area => "Scene"],
        ),
        XPalm.ConstantRUEModel(p.parameters[:RUE]),
        XPalm.CarbonOfferRm(),
        MultiScaleModel(
            model=XPalm.OrgansCarbonAllocationModel(p.parameters[:carbon_demand][:reserves][:cost_reserve_mobilization]),
            mapping=[
                :carbon_demand_organs => ["Leaf", "Internode", "Male", "Female"] .=> :carbon_demand,
                :carbon_allocation_organs => ["Leaf", "Internode", "Male", "Female"] .=> :carbon_allocation,
                PreviousTimeStep(:reserve_organs) => ["Leaf", "Internode"] .=> :reserve,
                PreviousTimeStep(:reserve)
            ],
        ),
        MultiScaleModel(
            model=XPalm.OrganReserveFilling(),
            mapping=[
                :potential_reserve_organs => ["Internode", "Leaf"] .=> :potential_reserve,
                :reserve_organs => ["Internode", "Leaf"] .=> :reserve,
            ],
        ),
        MultiScaleModel(
            model=XPalm.PlantBunchHarvest(),
            mapping=[
                :biomass_bunch_harvested_organs => ["Female"] .=> :biomass_bunch_harvested,
                :biomass_stalk_harvested_organs => ["Female"] .=> :biomass_stalk_harvested,
                :biomass_fruit_harvested_organs => ["Female"] .=> :biomass_fruit_harvested,
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
            model=XPalm.InitiationAgeFromPlantAge(),
            mapping=[:plant_age => "Plant",],
        ),
        # DegreeDaysFTSW(
        #     threshold_ftsw_stress=p.parameters[:phyllochron][:threshold_ftsw_stress],
        # ), #! we should use this one instead of DailyDegreeDaysSinceInit I think
        MultiScaleModel(
            model=XPalm.DailyDegreeDaysSinceInit(),
            mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
        ),
        MultiScaleModel(
            model=XPalm.SexDetermination(
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
            model=XPalm.ReproductiveOrganEmission(p.mtg),
            mapping=[:graph_node_count => "Scene", :phytomer_count => "Plant"],
        ),
        MultiScaleModel(
            model=XPalm.AbortionRate(
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
            model=XPalm.InfloStateModel(
                TT_flowering=p.parameters[:inflo][:TT_flowering],
                duration_abortion=p.parameters[:inflo][:duration_abortion],
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
                model=XPalm.InitiationAgeFromPlantAge(),
                mapping=[:plant_age => "Plant",],
            ),
            MultiScaleModel(
                model=XPalm.DailyDegreeDaysSinceInit(),
                mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
            ),
            MultiScaleModel(
                model=XPalm.RmQ10FixedN(
                    p.parameters[:respiration][:Internode][:Q10],
                    p.parameters[:respiration][:Internode][:Rm_base],
                    p.parameters[:respiration][:Internode][:T_ref],
                    p.parameters[:respiration][:Internode][:P_alive],
                    p.parameters[:nitrogen_content][:Internode],
                ),
                mapping=[PreviousTimeStep(:biomass),],
            ),
            XPalm.FinalPotentialInternodeDimensionModel(
                p.parameters[:potential_dimensions][:age_max_height],
                p.parameters[:potential_dimensions][:age_max_radius],
                p.parameters[:potential_dimensions][:min_height],
                p.parameters[:potential_dimensions][:min_radius],
                p.parameters[:potential_dimensions][:max_height],
                p.parameters[:potential_dimensions][:max_radius],
            ),
            XPalm.PotentialInternodeDimensionModel(
                p.parameters[:potential_dimensions][:inflexion_point_height],
                p.parameters[:potential_dimensions][:slope_height],
                p.parameters[:potential_dimensions][:inflexion_point_radius],
                p.parameters[:potential_dimensions][:slope_radius],
            ),
            XPalm.InternodeCarbonDemandModel(
                p.parameters[:carbon_demand][:internode][:stem_apparent_density],
                p.parameters[:carbon_demand][:internode][:respiration_cost]
            ),
            MultiScaleModel(
                model=XPalm.PotentialReserveInternode(
                    p.parameters[:nsc_max]
                ),
                mapping=[PreviousTimeStep(:biomass), PreviousTimeStep(:reserve)],
            ),
            XPalm.InternodeBiomass(
                initial_biomass=p.parameters[:potential_dimensions][:min_height] * p.parameters[:potential_dimensions][:min_radius] * p.parameters[:carbon_demand][:internode][:stem_apparent_density],
                respiration_cost=p.parameters[:carbon_demand][:internode][:respiration_cost]
            ),
            XPalm.InternodeDimensionModel(p.parameters[:carbon_demand][:internode][:stem_apparent_density]),
        ),
    "Leaf" => (
        MultiScaleModel(
            model=XPalm.DailyDegreeDaysSinceInit(),
            mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
        ),
        XPalm.FinalPotentialAreaModel(
            p.parameters[:potential_area][:age_first_mature_leaf],
            p.parameters[:potential_area][:leaf_area_first_leaf],
            p.parameters[:potential_area][:leaf_area_mature_leaf],
        ),
        XPalm.PotentialAreaModel(
            p.parameters[:potential_area][:inflexion_index],
            p.parameters[:potential_area][:slope],
        ),
        XPalm.LeafStateModel(),
        MultiScaleModel(
            model=XPalm.LeafRankModel(),
            mapping=[:rank => ["Phytomer"],],
        ),
        MultiScaleModel(
            model=XPalm.RankLeafPruning(p.parameters[:rank_leaf_pruning]),
            mapping=[:rank_phytomers => ["Phytomer" => :rank], :state_phytomers => ["Phytomer" => :state]],
        ),
        MultiScaleModel(
            model=XPalm.InitiationAgeFromPlantAge(),
            mapping=[:plant_age => "Plant",],
        ),
        MultiScaleModel(
            model=XPalm.LeafAreaModel(
                p.parameters[:lma_min],
                p.parameters[:leaflets_biomass_contribution],
                p.parameters[:potential_area][:leaf_area_first_leaf],
            ),
            mapping=[PreviousTimeStep(:biomass),],
        ),
        MultiScaleModel(
            model=XPalm.RmQ10FixedN(
                p.parameters[:respiration][:Leaf][:Q10],
                p.parameters[:respiration][:Leaf][:Rm_base],
                p.parameters[:respiration][:Leaf][:T_ref],
                p.parameters[:respiration][:Leaf][:P_alive],
                p.parameters[:nitrogen_content][:Leaf]
            ),
            mapping=[PreviousTimeStep(:biomass),],
        ),
        XPalm.LeafCarbonDemandModelPotentialArea(
            p.parameters[:lma_min],
            p.parameters[:carbon_demand][:leaf][:respiration_cost],
            p.parameters[:leaflets_biomass_contribution]
        ),
        MultiScaleModel(
            model=XPalm.PotentialReserveLeaf(
                p.parameters[:lma_min],
                p.parameters[:lma_max],
                p.parameters[:leaflets_biomass_contribution]
            ),
            mapping=[PreviousTimeStep(:leaf_area), PreviousTimeStep(:reserve)],
        ),
        XPalm.LeafBiomass(
            initial_biomass=p.parameters[:potential_area][:leaf_area_first_leaf] * p.parameters[:lma_min] /
                            p.parameters[:leaflets_biomass_contribution],
            respiration_cost=p.parameters[:carbon_demand][:leaf][:respiration_cost],
        ),
    ),
    "Male" => (
        MultiScaleModel(
            model=XPalm.InitiationAgeFromPlantAge(),
            mapping=[:plant_age => "Plant",],
        ),
        MultiScaleModel(
            model=XPalm.DailyDegreeDaysSinceInit(),
            mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
        ),
        XPalm.MaleFinalPotentialBiomass(
            p.parameters[:male][:male_max_biomass],
            p.parameters[:male][:age_mature_male],
            p.parameters[:male][:fraction_biomass_first_male],
        ),
        MultiScaleModel(
            model=XPalm.RmQ10FixedN(
                p.parameters[:respiration][:Male][:Q10],
                p.parameters[:respiration][:Male][:Rm_base],
                p.parameters[:respiration][:Male][:T_ref],
                p.parameters[:respiration][:Male][:P_alive],
                p.parameters[:nitrogen_content][:Male],
            ),
            mapping=[PreviousTimeStep(:biomass),],
        ),
        XPalm.MaleCarbonDemandModel(
            p.parameters[:male][:duration_flowering_male],
            p.parameters[:inflo][:TT_flowering],
            p.parameters[:carbon_demand][:male][:respiration_cost]
        ),
        XPalm.MaleBiomass(
            p.parameters[:carbon_demand][:male][:respiration_cost],
        ),
    ),
    "Female" => (
        MultiScaleModel(
            model=XPalm.InitiationAgeFromPlantAge(),
            mapping=[:plant_age => "Plant",],
        ),
        MultiScaleModel(
            model=XPalm.DailyDegreeDaysSinceInit(),
            mapping=[:TEff => "Plant",],
        ),
        MultiScaleModel(
            model=XPalm.RmQ10FixedN(
                p.parameters[:respiration][:Female][:Q10],
                p.parameters[:respiration][:Female][:Rm_base],
                p.parameters[:respiration][:Female][:T_ref],
                p.parameters[:respiration][:Female][:P_alive],
                p.parameters[:nitrogen_content][:Female],
            ),
            mapping=[PreviousTimeStep(:biomass),],
        ),
        XPalm.FemaleFinalPotentialFruits(
            p.parameters[:female][:age_mature_female],
            p.parameters[:female][:fraction_first_female],
            p.parameters[:female][:potential_fruit_number_at_maturity],
            p.parameters[:female][:potential_fruit_weight_at_maturity],
            p.parameters[:female][:stalk_max_biomass],
        ),
        MultiScaleModel(
            model=XPalm.NumberSpikelets(
                TT_flowering=p.parameters[:inflo][:TT_flowering],
                duration_dev_spikelets=p.parameters[:female][:duration_dev_spikelets],
            ),
            mapping=[PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm, PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand],
        ),
        MultiScaleModel(
            model=XPalm.NumberFruits(
                TT_flowering=p.parameters[:inflo][:TT_flowering],
                duration_fruit_setting=p.parameters[:female][:duration_fruit_setting],
            ),
            mapping=[PreviousTimeStep(:carbon_offer_plant) => "Plant" => :carbon_offer_after_rm, PreviousTimeStep(:carbon_demand_plant) => "Plant" => :carbon_demand],
        ),
        XPalm.FemaleCarbonDemandModel(
            p.parameters[:carbon_demand][:female][:respiration_cost],
            p.parameters[:carbon_demand][:female][:respiration_cost_oleosynthesis],
            p.parameters[:inflo][:TT_flowering],
            p.parameters[:female][:TT_harvest],
            p.parameters[:female][:duration_fruit_setting],
            p.parameters[:female][:oil_content],
            p.parameters[:female][:fraction_period_oleosynthesis],
            p.parameters[:female][:fraction_period_stalk],
        ),
        XPalm.FemaleBiomass(
            p.parameters[:carbon_demand][:female][:respiration_cost],
            p.parameters[:carbon_demand][:female][:respiration_cost_oleosynthesis],
        ),
        XPalm.BunchHarvest(),
    ),
    "RootSystem" => (
        MultiScaleModel(
            model=XPalm.DailyDegreeDaysSinceInit(),
            mapping=[:TEff => "Scene",], # Using TEff computed at scene scale
        ),
        # root_growth=RootGrowthFTSW(ini_root_depth=p.parameters[:ini_root_depth]),
        # soil_water=FTSW{RootSystem}(ini_root_depth=p.parameters[:ini_root_depth]),
    ),
    "Soil" => (
        # light_interception=Beer{Soil}(),
        MultiScaleModel(
            model=XPalm.FTSW(ini_root_depth=p.parameters[:ini_root_depth]),
            mapping=[:ET0 => "Scene", :aPPFD => "Scene"], # Using TEff computed at scene scale
        ),
        #! Root growth should be in the roots part, but it is a hard-coupled model with 
        #! the FSTW, so we need it here for now. Make changes to PlantSimEngine accordingly.
        MultiScaleModel(
            model=XPalm.RootGrowthFTSW(ini_root_depth=p.parameters[:ini_root_depth]),
            mapping=[:TEff => "Scene",], # Using TEff computed at scene scale
        ),
    )
)

dep(mapping);
to_initialize(mapping, p.mtg)

outs = Dict{String,Any}(
    "Scene" => (:lai, :scene_leaf_area, :aPPFD, :TEff),
    "Plant" => (:plant_age, :ftsw, :newPhytomerEmergence, :aPPFD, :plant_leaf_area, :carbon_assimilation, :carbon_offer_after_rm, :Rm, :TT_since_init, :TEff, :phytomer_count, :newPhytomerEmergence),
    # "Plant" => (:phytomers,),
    "Leaf" => (:Rm, :potential_area, :TT_since_init, :TEff),
    "Internode" => (:Rm, :potential_height, :carbon_demand),
    # "Male" => (:Rm,),
    # "Female" => (:Rm,),
    # "Leaf" => (:A, :carbon_demand, :carbon_allocation, :TT),
    # "Internode" => (:carbon_allocation,),
    "Soil" => (:TEff, :ftsw, :root_depth),
)



# p = Palm()
# @time sim = run!(p.mtg, mapping, meteo, outputs=outs, executor=SequentialEx());
@time sim = run!(p.mtg, mapping, m, outputs=outs, executor=SequentialEx());

df = outputs(sim, DataFrame, no_value=missing)
df_Internode = filter(row -> row.organ == "Internode", df)
df_scene = filter(row -> row.organ == "Scene", df)
df_plant = filter(row -> row.organ == "Plant", df)
df_soil = filter(row -> row.organ == "Soil", df)
df_leaf = filter(row -> row.organ == "Leaf", df)


lines(df_plant.phytomer_count)


lines(df_scene.scene_leaf_area)
lines(df_scene.lai)
lines(df_scene.scene_leaf_area)
lines(df_scene.TEff)
lines(df_plant.carbon_assimilation)