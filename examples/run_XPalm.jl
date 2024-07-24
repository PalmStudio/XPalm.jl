# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
using CairoMakie, AlgebraOfGraphics
using Dates
using DataFrames, CSV, Statistics
# using CairoMakie
using XPalm

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
meteo.T = meteo.Taverage
meteo.Rh .= (meteo.Rh_max .- meteo.Rh_min) ./ 2 ./ 100
rename!(meteo, :Date => :date)
meteo.duration .= Dates.Day(1)
nsteps = 912
m = Weather(meteo[1:nsteps, :])

begin
    p = Palm()
    model_mapping = Dict(
        "Scene" => (
            XPalm.ET0_BP(),
            DailyDegreeDays(),
            MultiScaleModel(
                model=XPalm.LAIModel(p.parameters[:scene_area]),
                mapping=[:leaf_area => ["Leaf"],],
            ),
            XPalm.Beer(k=p.parameters[:k]),
            XPalm.GraphNodeCount(length(p.mtg)), # to have the `graph_node_count` variable initialised in the status
        ),
        "Plant" => (
            # MultiScaleModel(
            #     model=DegreeDaysFTSW(
            #         threshold_ftsw_stress=p.parameters[:phyllochron][:threshold_ftsw_stress],
            #     ),
            #     mapping=[:ftsw => "Soil",],
            # ),
            DailyDegreeDays(),#! replace by `DegreeDaysFTSW`
            XPalm.DailyPlantAgeModel(),
            MultiScaleModel(
                model=XPalm.PhyllochronModel(
                    p.parameters[:phyllochron][:age_palm_maturity],
                    p.parameters[:phyllochron][:threshold_ftsw_stress],
                    p.parameters[:phyllochron][:production_speed_initial],
                    p.parameters[:phyllochron][:production_speed_mature],
                    length(traverse(p.mtg, x -> true, filter_fun=node -> symbol(node) == "Phytomer")),
                ),
                mapping=[:ftsw => "Soil",],
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
                mapping=[:aPPFD => "Scene", :scene_leaf_area => "Scene"],
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
        "Stem" => (
            MultiScaleModel(
                model=XPalm.StemBiomass(),
                mapping=[
                    :biomass_internodes => ["Internode"] .=> :biomass,
                ],
            ),
        ),
        "Phytomer" => (
            MultiScaleModel(
                model=XPalm.InitiationAgeFromPlantAge(),
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
                    model=DailyDegreeDaysSinceInit(),
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
                model=DailyDegreeDaysSinceInit(),
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
                model=DailyDegreeDaysSinceInit(),
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
                model=DailyDegreeDaysSinceInit(),
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
                model=DailyDegreeDaysSinceInit(),
                mapping=[:TEff => "Scene",], # Using TEff computed at scene scale
            ),
            # root_growth=RootGrowthFTSW(ini_root_depth=p.parameters[:ini_root_depth]),
            # soil_water=FTSW{RootSystem}(ini_root_depth=p.parameters[:ini_root_depth]),
        ),
        "Soil" => (
            MultiScaleModel(
                model=FTSW(ini_root_depth=p.parameters[:ini_root_depth]),
                mapping=[:ET0 => "Scene", :aPPFD => "Scene"], # Using TEff computed at scene scale
            ),
            #! Root growth should be in the roots part, but it is a hard-coupled model with 
            #! the FSTW, so we need it here for now. Make changes to PlantSimEngine accordingly.
            MultiScaleModel(
                model=RootGrowthFTSW(ini_root_depth=p.parameters[:ini_root_depth]),
                mapping=[:TEff => "Scene",], # Using TEff computed at scene scale
            ),
        )
    )

    to_initialize(model_mapping, p.mtg)

    outs = Dict{String,Any}(
        "Scene" => (:lai, :scene_leaf_area, :aPPFD, :TEff),
        "Plant" => (:plant_age, :newPhytomerEmergence, :aPPFD_plant, :plant_leaf_area, :carbon_assimilation, :carbon_offer_after_rm, :Rm, :TT_since_init, :TEff, :carbon_allocation, :carbon_demand_organs, :carbon_demand, :reserve, :carbon_offer_after_rm, :respiration_reserve_mobilization, :reserve_organs, :Rm_organs),
        # "Plant" => (:phytomers,),
        "Leaf" => (:Rm, :potential_area, :TT_since_init, :TEff, :biomass, :carbon_allocation, :carbon_demand, :leaf_area),
        "Internode" => (:Rm, :potential_height, :carbon_demand),
        # "Male" => (:Rm,),
        "Female" => (:Rm, :TT_since_init, :TEff, :biomass, :carbon_allocation, :carbon_demand, :carbon_demand_non_oil, :carbon_demand_oil, :carbon_demand_stalk, :biomass_stalk, :biomass_fruits,),
        # "Leaf" => (:A, :carbon_demand, :carbon_allocation, :TT),
        # "Internode" => (:carbon_allocation,),
        "Soil" => (:TEff, :ftsw, :root_depth),
    )

    # @time sim = run!(p.mtg, mapping, meteo, outputs=outs, executor=SequentialEx());
end
sim = run!(p.mtg, model_mapping, m, outputs=outs, executor=SequentialEx());
df = outputs(sim, DataFrame)

df_scene = filter(row -> row.organ == "Scene", df)
df_plant = filter(row -> row.organ == "Plant", df)
df_leaf = filter(row -> row.organ == "Leaf", df)
df_female = filter(row -> row.organ == "Female", df)
df_internode = filter(row -> row.organ == "Internode", df)

lines([df_plant.plant_leaf_area...])
lines([df_plant.aPPFD_plant...])
lines([df_scene.aPPFD...])
lines([df_scene.lai...])
lines([df_plant.carbon_assimilation...])
lines([df_plant.Rm...] ./ [df_plant.carbon_assimilation...]) # Should be around 0.5
lines([df_plant.reserve...]) #? always 0.0??

leaf_1 = filter(x -> x.node == 8, df_leaf)

lines([leaf_1.biomass...])
lines([leaf_1.carbon_allocation...])
lines([leaf_1.Rm...] ./ [leaf_1.carbon_allocation...])
lines([leaf_1.carbon_demand...])
lines([leaf_1.leaf_area...])

leaf_104 = filter(x -> x.node == 104, df_leaf)
lines([leaf_104.leaf_area...])
lines([leaf_104.potential_area...])
lines([leaf_104.biomass...])


# @time sim = run!(Palm().mtg, mapping, m[1], outputs=outs, executor=SequentialEx());
# graph = PlantSimEngine.GraphSimulation(Palm().mtg, model_mapping, nsteps=length(m), check=true, outputs=outs);
# @time sim = run!(graph, m, Constants(), nothing) # 0.5 millisecond per time-step
# graph.statuses["Leaf"][1]
# sim.statuses["Leaf"][1]
# graph.statuses["Internode"][1]

df_scene = filter(row -> row.organ == "Scene", df)
df_plant = filter(row -> row.organ == "Plant", df)
df_leaf = filter(row -> row.organ == "Leaf", df)
df_female = filter(row -> row.organ == "Female", df)
df_internode = filter(row -> row.organ == "Internode", df)

["Leaf", "Internode", "Male", "Female"]
findfirst(isnan, df_plant.Rm)
df_plant.Rm[273]
df_plant[274, :]
filter(row -> row.timestep == 274, df_leaf)
filter(row -> row.timestep == 273, df_female)
filter(row -> row.timestep == 274, df_female)


select!(filter(row -> row.timestep == 272, df_female), Not([:aPPFD_plant, :plant_leaf_area, :reserve, :plant_age, :carbon_assimilation, :scene_leaf_area, :lai, :respiration_reserve_mobilization, :newPhytomerEmergence, :aPPFD, :potential_height]))


filter(row -> row.timestep == 273, df_female)

df_node = filter(x -> x.node == 8, df_leaf)
select!(df_node, Not(names(df_node, Missing)))


df_node[912, :]
sum(outputs(sim)["Plant"][:Rm_organs][912][1])
findfirst(isnan, outputs(sim)["Plant"][:Rm_organs][912][1])

node = get_node(p.mtg, 128)
node.plantsimengine_status.Rm

traverse(p.mtg, node -> node, filter_fun=node -> hasproperty(node.plantsimengine_status, :Rm) ? isnan(node.plantsimengine_status.Rm) : false)
node = get_node(p.mtg, 196)
node.plantsimengine_status.Rm
node.plantsimengine_status.biomass
node.plantsimengine_status.carbon_allocation
node.plantsimengine_status


df_plant.biomass[912]
df_internode
df_plant.Rm[912]
df_node.biomass[912]
df_node.Rm[912]

select!(df_node, Not([:carbon_offer_after_rm, :plant_age, :carbon_assimilation, :newPhytomerEmergence, :aPPFD, :potential_height]))

df_plant[912, :carbon_demand]
df_plant[912, :]

sum(outputs(sim)["Plant"][:carbon_demand_organs][912][1])
df_plant[912, :]

carbon_demand_organs

df_scene.lai
data(df_plant) * AlgebraOfGraphics.mapping(:ftsw) |> draw()

df_leaf[findfirst(x -> x === NaN, df_leaf.Rm), :]
filter(x -> x.node == 8, df_leaf)