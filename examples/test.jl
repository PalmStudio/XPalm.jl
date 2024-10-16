# Import dependencies
using PlantMeteo, PlantSimEngine, MultiScaleTreeGraph
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
# using CairoMakie
using XPalm

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
meteo.T = meteo.Taverage
meteo.Rh .= (meteo.Rh_max .- meteo.Rh_min) ./ 2 ./ 100
m = Weather(meteo)

p = Palm()

mapping = Dict(
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
        MultiScaleModel(
            model=DegreeDaysFTSW(
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
            length(traverse(p.mtg, x -> true, filter_fun=node -> symbol(node) == "Phytomer")),
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
        # light_interception=Beer{Soil}(),
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

dep(mapping);
to_initialize(mapping, p.mtg)

# soft_dep_graphs_roots = PlantSimEngine.hard_dependencies(mapping; verbose=true);
# node = soft_dep_graphs_roots.roots["Plant"]
# var = Pair{Symbol,NamedTuple}[]
# organ = "Plant"
# full_vars_mapping = Dict(first(mod) => Dict(PlantSimEngine.get_mapping(last(mod))) for mod in mapping)

#! this is probably why it's not working:
# julia> full_vars_mapping[organ]
# Dict{Union{Symbol, PreviousTimeStep}, Union{Pair{String, Symbol}, Vector{Pair{String, Symbol}}}} with 15 entries:
#   :biomass_stalk_harvested_organs                       => ["Female"=>:biomass_stalk_harvested]
#   :carbon_allocation_organs                             => ["Leaf"=>:carbon_allocation, "Internode"=>:carbon_allocation, "Male"=>:carbon_allocation, "Female"=>:carbon_allocation]
#   :reserve_organs                                       => ["Internode"=>:reserve, "Leaf"=>:reserve]
#   :carbon_demand_organs                                 => ["Leaf"=>:carbon_demand, "Internode"=>:carbon_demand, "Male"=>:carbon_demand, "Female"=>:carbon_demand]
#   :ftsw                                                 => "Soil"=>:ftsw
#   :biomass_fruit_harvested_organs                       => ["Female"=>:biomass_fruit_harvested]
#   :Rm_organs                                            => ["Leaf"=>:Rm, "Internode"=>:Rm, "Male"=>:Rm, "Female"=>:Rm]
#   PreviousTimeStep(:reserve, :carbon_allocation)        => ""=>:reserve
#   PreviousTimeStep(:reserve_organs, :carbon_allocation) => ["Leaf"=>:reserve, "Internode"=>:reserve]
#   :scene_leaf_area                                      => "Scene"=>:scene_leaf_area
#   :graph_node_count                                     => "Scene"=>:graph_node_count
#   :aPPFD                                                => "Scene"=>:aPPFD
#   :leaf_area                                            => ["Leaf"=>:leaf_area]
#   :potential_reserve_organs                             => ["Internode"=>:potential_reserve, "Leaf"=>:potential_reserve]
#   :biomass_bunch_harvested_organs                       => ["Female"=>:biomass_bunch_harvested]
#! the variable `:reserve_organs` appears twice, once mapped as is, and once mapped to the values from the previous day.
#! this is because the model `XPalm.OrganReserveFilling` needs the current values, while `OrgansCarbonAllocationModel` needs the values from 
#! the previous day to avoid a cyclic dependency.

# full_vars_mapping[organ]
# PlantSimEngine.traverse_dependency_graph!(node, x -> PlantSimEngine.variables_multiscale(x, organ, full_vars_mapping, NamedTuple()), var)
# dep_graph = PlantSimEngine.soft_dependencies_multiscale(soft_dep_graphs_roots, mapping)
# mapped_vars = PlantSimEngine.mapped_variables(mapping, soft_dep_graphs_roots, verbose=false)
# rev_mapping = PlantSimEngine.reverse_mapping(mapped_vars, all=false)
# organ = "Plant";
# soft_dep_graph, ins, outs = soft_dep_graphs_roots.roots[organ];
# proc = :carbon_allocation;
# i = soft_dep_graph[proc];
# soft_deps = PlantSimEngine.search_inputs_in_output(proc, ins, outs)

# :reserve => 0.0
# :reserve_organs => MappedVar{MultiNodeMapping,Symbol,Vector{Symbol},Float64}(MultiNodeMapping(["Internode", "Leaf"]), :reserve_organs, [:reserve, :reserve], 0.0)

outs = Dict{String,Any}(
    "Scene" => (:lai, :scene_leaf_area, :aPPFD, :TEff),
    "Plant" => (:plant_age, :ftsw, :newPhytomerEmergence, :aPPFD_plant, :plant_leaf_area, :carbon_assimilation, :carbon_offer_after_rm, :Rm, :TT_since_init, :TEff),
    # "Plant" => (:phytomers,),
    "Leaf" => (:Rm, :potential_area, :TT_since_init, :TEff),
    "Internode" => (:Rm, :potential_height, :carbon_demand),
    # "Male" => (:Rm,),
    # "Female" => (:Rm,),
    # "Leaf" => (:A, :carbon_demand, :carbon_allocation, :TT),
    # "Internode" => (:carbon_allocation,),
    "Soil" => (:TEff, :ftsw, :root_depth),
)

p = Palm()
# @time sim = run!(p.mtg, mapping, meteo, outputs=outs, executor=SequentialEx());
@time sim = run!(p.mtg, mapping, m, outputs=outs, executor=SequentialEx());

df = outputs(sim, DataFrame)
df_Internode = filter(row -> row.organ == "Internode", df)
df_scene = filter(row -> row.organ == "Scene", df)
df_plant = filter(row -> row.organ == "Plant", df)
df_soil = filter(row -> row.organ == "Soil", df)
df_leaf = filter(row -> row.organ == "Leaf", df)

df_scene.TEff
df_plant.TEff

sim.dependency_graph.roots["Scene"=>:thermal_time].simulation_id
sim.dependency_graph.roots["Scene"=>:thermal_time].children[1]

node = sim.dependency_graph.roots["Scene"=>:thermal_time].children[1]
any([p.simulation_id[1] <= node.simulation_id[1] for p in node.parent])

sim.dependency_graph.roots["Scene"=>:thermal_time].children[1].children[2]

sim.dependency_graph.roots["Scene"=>:thermal_time].children[1].children[2].simulation_id

df_soil.ftsw
df_plant.ftsw
df_plant.plant_age
df_plant.TEff
df_plant.TT_since_init
df_plant.newPhytomerEmergence
df_plant.plant_leaf_area
df_leaf.potential_area
df_leaf.TT_since_init
df_leaf.TEff
df_Internode.carbon_demand


df_scene.scene_leaf_area
df_scene.TEff

df_plant.carbon_assimilation
df_plant.Rm_plant
df_plant.carbon_offer_after_rm

print(df_plant.plant_leaf_area[1:2])
print(df_plant.Rm[1])
print(df_plant.carbon_assimilation[1:2])
print(df_plant.Rm_plant[1:2])
print(df_plant.carbon_offer_after_rm[1:2])


df_leaf = filter(row -> row.organ == "Leaf", df)
df_leaf.Rm[1:2]
df_plant.Rm_plant[1:2]

df_plant.aPPFD_plant # mol[PAR] plant⁻¹ d⁻¹
df_plant.plant_leaf_area # m2 leaves

df_plant.aPPFD_plant ./ df_plant.plant_leaf_area # mol[PAR] m[leaf]⁻² d⁻¹
# μmol[PAR] m[leaf]⁻² s⁻¹:
A = (df_plant.aPPFD_plant ./ df_plant.plant_leaf_area) * 1e6 / (60 * 60 * 24)

nleaves = length(traverse(p.mtg, x -> true, filter_fun=node -> symbol(node) == "Leaf"))
nleaves


@edit PlantSimEngine.init_simulation(p.mtg, mapping; nsteps=1, outputs=outs, type_promotion=nothing, check=true, verbose=true)

statuses, status_templates, map_other_scales, var_need_init = PlantSimEngine.init_statuses(p.mtg, mapping; type_promotion=nothing, check=true)
statuses

statuses["Scene"][1].TEff = 2.0
statuses["Soil"][1].TEff

statuses["Leaf"][1].leaf_area = 2.0
statuses["Scene"][1].leaf_area

status_templates["Scene"]
status_templates["Scene"][:TEff]
status_templates["Soil"][:TEff][] = 5.0
status_templates["RootSystem"][:TEff]

status_templates["Leaf"][:TEff]
status_templates["Plant"][:TEff]
status_templates["Internode"][:TEff]

status_templates["Leaf"][:TEff][] = 2.0
status_templates["Internode"][:TEff] = 3.0


organs_mapping, var_outputs_from_mapping = PlantSimEngine.compute_mapping(mapping, nothing)

organs_mapping["Scene"]["Scene"].TEff
organs_mapping["Soil"]["Scene"]
organs_mapping["RootSystem"]["Scene"]

organs_mapping["Plant"]
organs_mapping["Leaf"]
organs_mapping["Internode"]


organs_statuses_dict = Dict{String,Dict{Symbol,Any}}()
dict_mapped_vars = Dict{Pair,Any}()


organ = "Soil"
node_models = PlantSimEngine.parse_models(PlantSimEngine.get_models(mapping[organ]))
st = PlantSimEngine.get_status(mapping[organ]) # User status

if isnothing(st)
    st = NamedTuple()
else
    st = NamedTuple(st)
end

# Add the variables that are defined as multiscale (coming from other scales):
if haskey(organs_mapping, organ)
    st_vars_mapped = (; zip(PlantSimEngine.vars_from_mapping(organs_mapping[organ]), PlantSimEngine.vars_type_from_mapping(organs_mapping[organ]))...)
    !isnothing(st_vars_mapped) && (st = merge(st, st_vars_mapped))
end