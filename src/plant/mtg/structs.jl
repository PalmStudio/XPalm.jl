abstract type OrganState end

struct Initiated <: OrganState end
struct Spear <: OrganState end
struct Opened <: OrganState end
struct Pruned <: OrganState end
struct Scenescent <: OrganState end
struct Aborted <: OrganState end
struct Flowering <: OrganState end
struct Bunch <: OrganState end
struct OleoSynthesis <: OrganState end
struct Growing <: OrganState end
struct Snag <: OrganState end

abstract type Organ end

struct Soil end
struct Plant end
struct RootSystem <: Organ end
struct Stem <: Organ end

"""
    Phytomer(state)

A phytomer
"""
struct Phytomer <: Organ end

"""
    Internode(state)

An internode, which has a state of type [`InternodeState`](@ref) that can be either:

- `Growing`: has both growth and maintenance respiration
- `Snag`: has maintenance respiration only, and no leaf 
or reproductive organs
"""
mutable struct Internode{S} <: Organ where {S<:OrganState}
    state::S
end

Internode() = Internode(Growing())

"""
    Leaf(state)

A leaf, which has a state of type [`LeafState`](@ref) that can be either:

- `Initiated`: in initiation phase (cell division until begining of elongation)
- `Spear`: spear phase, almost fully developped, but leaflets are not yet deployed
- `Opened`: deployed and photosynthetically active
- `Pruned`: dead and removed from the plant
- `Scenescent`: dead but still on the plant
"""
mutable struct Leaf <: Organ
    state::OrganState
end
Leaf() = Leaf(Initiated())

abstract type ReproductiveOrgan <: Organ end

"""
    Male(state)

A male inflorescence, which has a state that can be either:

- `Initiated`: in initiation phase (cell division)
- `Aborted`
- `Flowering`
- `Scenescent`: dead but still on the plant
- `Pruned`: removed from the plant
"""
mutable struct Male <: ReproductiveOrgan
    state::OrganState
end

Male() = Male(Initiated())


"""
    Female(state)

A female inflorescence, which has a state that can be either:

- `Initiated`: in initiation phase (cell division)
- `Aborted`
- `Flowering`
- `Bunch`: the bunch of fruits is developping
- `OleoSynthesis`: the inflorescence is in the process of oleosynthesis
- `Scenescent`: dead but still on the plant
- `Pruned`: removed from the plant (*e.g.* harvested)
"""
mutable struct Female
    state::OrganState
end

Female() = Female(Initiation())

# """
#     increment_rank!(palm::Palm)

# Increment the rank of all phytomers on the palm. 
# This is called whenever a new phytomer is emmitted.
# """
# function increment_rank!(palm::Palm)
#     MultiScaleTreeGraph.transform!(
#         palm.mtg,
#         :rank => (x -> x + 1) => :rank
#     )
#     return nothing
# end


"""
    Palm(;
        nsteps=1,
        initiation_age=0,
        parameters=default_parameters(),
        model_list=main_models_definition(parameters, nsteps)
    )

Create a new scene with one Palm plant.

# Arguments

- `nsteps`: number of time steps to run the simulation for (default: 1, should match the number of rows in the meteo data)
- `initiation_age`: date of the first phytomer initiation (default: 0)
- `parameters`: a dictionary of parameters (default: `default_parameters()`)
- `model_list`: a dictionary of models (default: `main_models_definition(parameters, nsteps)`)
"""
mutable struct Palm{T} <: Organ
    mtg::MultiScaleTreeGraph.Node
    initiation_age::Int
    parameters::T
end

abstract type InitState end

function default_parameters()
    p = Dict(
        :k => 0.5, # light extinction coefficient
        :RUE => 4.8, # Radiation use efficiency (gC MJ[PAR]-1)
        :SRL => 0.4, # Specific Root Length (m g-1)
        :lma_min => 80.0, # min leaf mass area (g m-2)
        :lma_max => 200.0, # max  leaf mass area (g m-2)
        :leaflets_biomass_contribution => 0.35,
        :seed_reserve => 100, # seed reserve (from which the plant grows)
        :nsc_max => 0.3, # Maximum non-structural carbohydrates content in the stem.
        :RL0 => 5.0, # Root length at emergence (m)
        :respiration => Dict(
            :Internode => Dict(
                :Q10 => 1.7,  # Dufrene et al. (2005)
                :Rm_base => 0.005, # Dufrene et al. (1990), Oleagineux.
                :T_ref => 25.0,
                :P_alive => 0.21, # Dufrene et al. (2005)
            ),
            :Leaf => Dict(
                :Q10 => 2.1,
                :Rm_base => 0.083, # Dufrene et al. (1990), Oleagineux.
                :T_ref => 25.0,
                :P_alive => 0.90,
            ),
            :Bunch => Dict(
                :Q10 => 2.1,
                :Rm_base => 0.0022, # Kraalingen et al. 1989, AFM
                :T_ref => 25.0,
                :P_alive => 0.50,
            ),
            :Male => Dict( ## to check 
                :Q10 => 2.1,
                :Rm_base => 0.0022, # Kraalingen et al. 1989, AFM
                :T_ref => 25.0,
                :P_alive => 0.50,
            ),
            :RootSystem => Dict(
                :Q10 => 2.1,
                :Rm_base => 0.0022, # Dufrene et al. (1990), Oleagineux.
                :T_ref => 25.0,
                :P_alive => 0.80,
            ),
        ),
        :nitrogen_content => Dict(
            :Stem => 0.004,
            :Internode => 0.004,
            :Leaf => 0.025,
            :Female => 0.01,
            :Male => 0.01,
            :RootSystem => 0.008,
        ),
        :ini_root_depth => 100.0,
        :potential_area => Dict(
            :leaf_area_first_leaf => 0.0015, # leaf potential area for the first leaf (m2)
            :leaf_area_mature_leaf => 12.0, # leaf potential area for a mature leaf (m2)
            :age_first_mature_leaf => 8 * 365, # age of the first mature leaf (days)
            :inflexion_index => 560.0,
            :slope => 100.0,
        ),
        :potential_dimensions => Dict(
            :age_max_height => 8 * 365,
            :age_max_radius => 8 * 365,
            :min_height => 2e-3,
            :min_radius => 2e-3,
            :max_height => 0.03,
            :max_radius => 0.30,
            :inflexion_point_height => 900.0,
            :slope_height => 150.0,
            :inflexion_point_radius => 900.0,
            :slope_radius => 150.0,
        ),
        :phyllochron => Dict(
            :age_palm_maturity => 8 * 365, # age of the palm maturity (days)
            :threshold_ftsw_stress => 0.3, # threshold of FTSW for stress, SMART-RI considers this value to be at 0.5
            :production_speed_initial => 0.0111, # initial production speed (leaf.day-1.degreeC-1)
            :production_speed_mature => 0.0074, # production speed at maturity (leaf.day-1.degreeC-1)
        ),
        :rank_leaf_pruning => 50,
        :carbon_demand => Dict(
            :leaf => Dict(
                :respiration_cost => 1.44,
            ),
            :internode => Dict(
                :stem_apparent_density => 300000.0, # g m-3
                :respiration_cost => 1.44, # g g-1
            ),
            :male => Dict(
                :respiration_cost => 1.44, # g g-1
            ),
            :reserves => Dict(
                :cost_reserve_mobilization => 1.667
            )
        ),
        :bunch => Dict(
            :TT_flowering => 6300.0,
            :duration_sex_determination => 1350.0,
            :duration_abortion => 540.0,
            :sex_ratio_min => 0.2,
            :sex_ratio_ref => 0.6,
            :abortion_rate_max => 0.8,
            :abortion_rate_ref => 0.2,
            :random_seed => 1,
            :age_max_coefficient => 8.0 * 365.0,
            :min_coefficient => 0.3,
            :max_coefficient => 1.0,
        ),
        :male => Dict(
            :TT_flowering => 6300.0,
            :duration_flowering_male => 1800.0,
            :duration_abortion => 540.0,
            :male_max_biomass => 1200.0,
            :age_mature_male => 8 * 365,
            :fraction_biomass_first_male => 0.3,
        ),
    )
    push!(p,
        :biomass_dry => Dict(
            :Stem => 0.1,
            :Internode => 2.0,
            :Leaf => 2.0,
            :RootSystem => p[:RL0] / p[:SRL]
        )
    )
    return p
end

function Palm(;
    nsteps=1,
    initiation_age=0,
    parameters=default_parameters(),
    model_list=main_models_definition(parameters, nsteps)
)

    scene = MultiScaleTreeGraph.Node(
        1,
        NodeMTG("/", "Scene", 1, 0),
        Dict{Symbol,Any}(
            :models => copy(model_list["Scene"]),
            :area => 10000 / 136.0, # scene area, m2
        ),
        # type=Scene()
    )

    soil = MultiScaleTreeGraph.Node(
        scene,
        NodeMTG("+", "Soil", 1, 1),
        Dict{Symbol,Any}(
            :models => copy(model_list["Soil"]),
        ),
        type=Plant()
    )

    plant = MultiScaleTreeGraph.Node(
        scene,
        NodeMTG("+", "Plant", 1, 1),
        Dict{Symbol,Any}(
            :models => copy(model_list["Plant"]),
            :parameters => parameters,
            :all_models => model_list,
        ),
        type=Plant()
    )

    roots = MultiScaleTreeGraph.Node(
        plant,
        NodeMTG("+", "RootSystem", 1, 2),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age,
            :depth => parameters[:RL0], # total exploration depth m
            :models => copy(model_list["RootSystem"]),
        ),
        type=RootSystem()
    )

    stem = MultiScaleTreeGraph.Node(
        plant,
        NodeMTG("+", "Stem", 1, 2),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age, # date of initiation / creation
            :models => copy(model_list["Stem"]),
        ),
        type=Stem()
    )

    phyto = MultiScaleTreeGraph.Node(stem, NodeMTG("/", "Phytomer", 1, 3),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age, # date of initiation / creation
            :models => copy(model_list["Phytomer"]),
        ),
        type=Phytomer(),
    )

    internode = MultiScaleTreeGraph.Node(phyto, NodeMTG("/", "Internode", 1, 4),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age, # date of initiation / creation
            :models => copy(model_list["Internode"]),
        ),
        type=Internode(),
    )

    leaf = MultiScaleTreeGraph.Node(internode, NodeMTG("+", "Leaf", 1, 4),
        Dict{Symbol,Any}(
            :initiation_age => initiation_age, # date of initiation / creation
            :models => copy(model_list["Leaf"]),
        ),
        type=Leaf(),
    )

    # Initilialise the number of phytomers:
    plant[:models].status[1].phytomers = 1

    # Initialise the final potential area of the first leaf (this computation is done only once in the model):
    leaf[:models].status[1].final_potential_area = parameters[:potential_area][:leaf_area_first_leaf]
    # And compute the leaf area as one percent of the potential area:
    leaf[:models].status[1].leaf_area = leaf[:models].status[1].final_potential_area * 0.01

    plant[:models].status[1].leaf_area = leaf[:models].status[1].leaf_area
    # Initialise the LAI:
    scene[:models].status[1].lai = leaf[:models].status[1].leaf_area / scene[:area] # m2 leaf / m2 soil

    leaf[:models].status[1].biomass =
        leaf[:models].status[1].leaf_area * parameters[:lma_min] /
        parameters[:leaflets_biomass_contribution]

    internode[:models].status[1].biomass = 0.0 # Just for Rm, it is then recomputed

    leaf[:models].status[1].reserve = 0.0
    # Put the reserves from the seed at sowing:
    internode[:models].status[1].reserve = parameters[:seed_reserve]
    # stem[:models].status[1].reserve = 0.0
    plant[:models].status[1].reserve = 0.0
    internode[:models].status[1].final_potential_height = parameters[:potential_dimensions][:min_height]
    internode[:models].status[1].final_potential_radius = parameters[:potential_dimensions][:min_radius]

    plant[:phytomer_count] = 1
    plant[:mtg_node_count] = length(scene)
    plant[:last_phytomer] = phyto

    return Palm(scene, initiation_age, parameters)
end