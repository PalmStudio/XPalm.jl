"""
    Palm(;
        nsteps=1,
        initiation_age=0,
        parameters=default_parameters(),
        model_list=model_mapping(parameters, nsteps)
    )

Create a new scene with one Palm plant.

# Arguments

- `nsteps`: number of time steps to run the simulation for (default: 1, should match the number of rows in the meteo data)
- `initiation_age`: date of the first phytomer initiation (default: 0)
- `parameters`: a dictionary of parameters (default: `default_parameters()`)
- `model_list`: a dictionary of models (default: `model_mapping(parameters, nsteps)`)
"""
mutable struct Palm{T}
    mtg::Node
    initiation_age::Int
    parameters::T
end

function default_parameters()

    # Computation of the average maintenance respiration coefficient for a leaf, based on Dufrene (1990):
    tot_prop = 7.5 + 13.6 + 9.1
    rachis_proportion = 9.1 / tot_prop
    petiole = 13.6 / tot_prop
    leaflets = 7.5 / tot_prop

    rachis_proportion + petiole + leaflets ≈ 1.0 || error("The sum of the proportions should be equal to 1.0")
    Mr_leaf = 0.0018 * rachis_proportion + 0.0022 * petiole + 0.0083 * leaflets

    p = OrderedDict{String,Any}(
        "plot" => Dict(
            "scene_area" => 10000 / 136.0, # scene area in m-2, area occupied for one plant
            "latitude" => 0.97,
            "altitude" => 50.0,
        ),
        "management" => Dict(
            "rank_leaf_pruning" => 50,
        ),
        "radiation" => Dict(
            "k" => 0.5, # light extinction coefficient
            "RUE" => 4.8, # Radiation use efficiency (gC MJ[PAR]-1)
            "threshold_ftsw" => 0.3,
        ),
        "reserves" => Dict(
            "nsc_max" => 0.3, # Maximum non-structural carbohydrates content in the stem.
        ),
        "mass_and_dimensions" => Dict(
            "roots" => Dict(
                "RL0" => 5.0, # Root length at emergence (m)
                "SRL" => 0.4, # Specific Root Length (m g-1)
            ),
            "leaf" => Dict(
                "lma_min" => 80.0, # min leaf mass area (g m-2)
                "lma_max" => 200.0, # max leaf mass area (g m-2)
            )
        ),
        "respiration" => Dict(
            "Internode" => Dict(
                "Mr" => 0.005, # Dufrene (1990)
                "Q10" => 1.7,  # Dufrene et al. (2005)
                "T_ref" => 25.0, # Dufrene et al. (1990), gives Rm_base commpared to all dry mass (not just living biomass)
                "P_alive" => 0.21, # Dufrene et al. (2005)
            ),
            "Leaf" => Dict(
                "Mr" => Mr_leaf, # Or 0.0022 for the rachis, she also gives the proportion of each so we could compute something in-between
                "Q10" => 2.1,
                "T_ref" => 25.0,
                "P_alive" => 0.90,
            ),
            "Female" => Dict(
                "Mr" => 0.0022, # Kraalingen et al. 1989, AFM (and 1985 too)
                "Q10" => 2.1,
                "T_ref" => 25.0,
                "P_alive" => 0.50,
            ),
            "Male" => Dict( ## to check 
                "Mr" => 0.0121, # Kraalingen et al. 1989, AFM
                "Q10" => 2.1,
                "T_ref" => 25.0,
                "P_alive" => 0.50,
            ),
            "RootSystem" => Dict(
                # Dufrene et al. (1990), Oleagineux:
                "Q10" => 2.1,
                "Turn" => 0.036,
                "Prot" => 6.25,
                "N" => 0.008,
                "Gi" => 0.07,
                "Mx" => 0.005,
                "T_ref" => 25.0,
                "P_alive" => 0.80,
            ),
        ),
        # "nitrogen_content" => Dict(
        #     "Stem" => 0.004,
        #     "Internode" => 0.004,
        #     "Leaf" => 0.025,
        #     "Female" => 0.01,
        #     "Male" => 0.01,
        #     "RootSystem" => 0.008,
        # ),
        "water" => Dict(
            "ini_root_depth" => 100.0,
            "field_capacity" => 0.25,
            "wilting_point_1" => 0.05,
            "thickness_1" => 200.0,
            "wilting_point_2" => 0.05,
            "thickness_2" => 2000.0,
            "initial_water_content" => 0.25,
            "Kc" => 1.0,
            "evaporation_threshold" => 0.5,
            "transpiration_threshold" => 0.5,
        ),
        "dimensions" => Dict(
            "internode" => Dict(
                "age_max_height" => 8 * 365,
                "age_max_radius" => 8 * 365,
                "min_height" => 2e-3,
                "min_radius" => 2e-3,
                "max_height" => 0.03,
                "max_radius" => 0.30,
                "inflexion_point_height" => 900.0,
                "slope_height" => 150.0,
                "inflexion_point_radius" => 900.0,
                "slope_radius" => 150.0,
            ),
            "leaf" => Dict(
                "leaf_area_first_leaf" => 0.02, # leaf potential area for the first leaf (m2)
                "length_first_leaf" => 0.3, # length of the first leaf (m)
                "leaf_area_mature_leaf" => 12.0, # leaf potential area for a mature leaf (m2)
                "age_first_mature_leaf" => 8 * 365, # age of the first mature leaf (days)
                "inflexion_index" => 337.5,
                "slope" => 100.0,
            ),
        ),
        "phyllochron" => Dict(
            "age_palm_maturity" => 8 * 365, # age of the palm maturity (days)
            "threshold_ftsw_stress" => 0.3, # threshold of FTSW for stress, SMART-RI considers this value to be at 0.5
            "production_speed_initial" => 0.0111, # initial production speed (leaf.day-1.degreeC-1)
            "production_speed_mature" => 0.0074, # production speed at maturity (leaf.day-1.degreeC-1)
        ),
        "carbon_demand" => Dict(
            "leaf" => Dict(
                "respiration_cost" => 1.44,
            ),
            "internode" => Dict(
                "apparent_density" => 300000.0, # g m-3
                "carbon_concentration" => 0.5, # g g-1
                "respiration_cost" => 1.44, # g g-1
            ),
            "male" => Dict(
                "respiration_cost" => 1.44, # g g-1
            ),
            "female" => Dict(
                "respiration_cost" => 1.44, # g g-1
                "respiration_cost_oleosynthesis" => 3.2, # g g-1
            ),
            "reserves" => Dict(
                "cost_reserve_mobilization" => 1.667
            )
        ),
        "biomass" => Dict(
            "male" => Dict(
                "max_biomass" => 174.852, # in carbon, so 1200g in dry mass -> 1200 x 0.4857 gC g-1 dry mass x 0.3 dry mass content (0.7 water content)
                "fraction_biomass_first_male" => 0.3,
            ),
            "leaf" => Dict(
                "leaflets_biomass_contribution" => 0.35,
            ),
        ),
        "reproduction" => Dict(
            "sex_ratio" => Dict(
                "sex_ratio_min" => 0.2,
                "sex_ratio_ref" => 0.6,
                "random_seed" => 1,
            ),
            "abortion" => Dict(
                "abortion_rate_max" => 0.8,
                "abortion_rate_ref" => 0.2,
                "random_seed" => 1,
            ),
            "yield_formation" => Dict(
                "fraction_first_female" => 0.30,
                "potential_fruit_number_at_maturity" => 2000,
                "potential_fruit_weight_at_maturity" => 6.5, # g
                "stalk_max_biomass" => 2100.0,
                "oil_content" => 0.25,
            ),
        ),
        "phenology" => Dict(
            "inflorescence" => Dict(
                "TT_flowering" => 10530.0, # TT_Harvest - (180 days * 9°C days-1 in average), see Van Kraalingen et al. 1989
                "duration_sex_determination" => 1350.0,
                "duration_abortion" => 540.0,
            ),
            "male" => Dict(
                "duration_flowering_male" => 1800.0,
                "age_mature_male" => 8.0 * 365,),
            "female" => Dict(
                "days_increase_number_fruits" => 2379, # in days
                "days_maximum_number_fruits" => 6500,
                "duration_fruit_setting" => 405.0,
                "duration_dev_spikelets" => 675.0,
                "duration_bunch_development" => 1215.0, # 90 phytomers until harvest (60 growing + 30 opened) x 9°C days-1 in average per day x 15 days
                "fraction_period_oleosynthesis" => 0.8,
                "fraction_period_stalk" => 0.2,
            ),
        ),
    )
    push!(p,
        "biomass_dry" => Dict(
            "Stem" => 0.1,
            "Internode" => 2.0,
            "Leaf" => 2.0,
            "RootSystem" => p["mass_and_dimensions"]["roots"]["RL0"] / p["mass_and_dimensions"]["roots"]["SRL"]
        )
    )

    push!(p, "vpalm" => VPalm.default_parameters())

    return p
end

"""
    Palm(; initiation_age=0, parameters=default_parameters())


Create a new scene with one Palm plant. The scene contains a soil, a plant, a root system, a stem, a phytomer, an internode, and a leaf.

# Arguments

- `initiation_age`: days elapsed since the first phytomer initiation (default: 0)
- `parameters`: a dictionary of parameters (default: `default_parameters()`)

# Returns

- a `Palm` object
"""
function Palm(; initiation_age=0, parameters=default_parameters(), architecture=true)
    # Parameters should be a Dict{AbstractString,Any}:
    if !(typeof(parameters) <: Dict{AbstractString})
        @info "`parameters` should be a Dict{AbstractString,Any}, converting using: `Dict{AbstractString,Any}(string(k) => v for (k, v) in parameters)`"
        parameters = Dict{AbstractString,Any}(string(k) => v for (k, v) in parameters)
    end

    scene = Node(1, NodeMTG("/", "Scene", 1, 0), Dict{Symbol,Any}(),)
    architecture && (scene.vpalm_rng = Random.MersenneTwister(parameters["vpalm"]["seed"]))
    soil = Node(scene, NodeMTG("+", "Soil", 1, 1),)

    plant = Node(scene, NodeMTG("+", "Plant", 1, 1), Dict{Symbol,Any}(:parameters => parameters,),)

    roots = Node(
        plant, NodeMTG("+", "RootSystem", 1, 2),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age,
            # :depth => parameters["RL0"], # total exploration depth m
        ),
    )

    stem = Node(
        plant, NodeMTG("+", "Stem", 1, 2),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age, # date of initiation / creation
        ),
    )

    phyto = Node(
        stem, NodeMTG("/", "Phytomer", 1, 3),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age, # date of initiation / creation
        ),
    )

    internode = Node(
        phyto, NodeMTG("/", "Internode", 1, 4),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age, # date of initiation / creation
        ),
    )

    leaf = Node(
        internode, NodeMTG("+", "Leaf", 1, 4),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age, # date of initiation / creation
        ),
    )

    architecture && VPalm.init_attributes_seed!(plant, parameters; rng=scene.vpalm_rng)

    return Palm(scene, initiation_age, parameters)
end

# Print the Palm structure nicely:
function Base.show(io::IO, p::Palm)
    println(io, "Scene with a palm density of $(1 / p.parameters["plot"]["scene_area"] * 10000) palms ha⁻¹. \nGraph:")
    println(io, p.mtg)
end