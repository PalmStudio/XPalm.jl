abstract type OrganState end

struct Initiation <: OrganState end
struct Spear <: OrganState end
struct Opened <: OrganState end
struct Pruned <: OrganState end
struct Scenescent <: OrganState end
struct Abortion <: OrganState end
struct Flowering <: OrganState end
struct Bunch <: OrganState end
struct OleoSynthesis <: OrganState end
struct Growing <: OrganState end
struct Snag <: OrganState end

abstract type Organ end

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
struct Internode{S} <: Organ where {S<:OrganState}
    state::S
end

Internode() = Internode(Growing)

"""
    Leaf(state)

A leaf, which has a state of type [`LeafState`](@ref) that can be either:

- `Initiation`: in initiation phase (cell division until begining of elongation)
- `Spear`: spear phase, almost fully developped, but leaflets are not yet deployed
- `Opened`: deployed and photosynthetically active
- `Pruned`: dead and removed from the plant
- `Scenescent`: dead but still on the plant
"""
struct Leaf{S} <: Organ where {S<:OrganState}
    state::S
end
Leaf() = Leaf(Initiation)

abstract type ReproductiveOrgan <: Organ end

"""
    Male(state)

A male inflorescence, which has a state that can be either:

- `Initiation`: in initiation phase (cell division)
- `Abortion`
- `Flowering`
- `Scenescent`: dead but still on the plant
- `Pruned`: removed from the plant
"""
struct Male{S} <: ReproductiveOrgan where {S<:OrganState}
    state::String
end

"""
    Female(state)

A female inflorescence, which has a state that can be either:

- `Initiation`: in initiation phase (cell division)
- `Abortion`
- `Flowering`
- `Bunch`: the bunch of fruits is developping
- `OleoSynthesis`: the inflorescence is in the process of oleosynthesis
- `Scenescent`: dead but still on the plant
- `Pruned`: removed from the plant (*e.g.* harvested)
"""
struct Female{S} <: ReproductiveOrgan where {S<:OrganState}
    state::String
end

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
        initiation_day=0,
        parameters=default_parameters(),
        model_list=main_models_definition(parameters, nsteps)
    )

Create a new scene with one Palm plant.

# Arguments

- `nsteps`: number of time steps to run the simulation for (default: 1, should match the number of rows in the meteo data)
- `initiation_day`: date of the first phytomer initiation (default: 0)
- `parameters`: a dictionary of parameters (default: `default_parameters()`)
- `model_list`: a dictionary of models (default: `main_models_definition(parameters, nsteps)`)
"""
mutable struct Palm{T} <: Organ
    mtg::MultiScaleTreeGraph.Node
    initiation_day::Int
    parameters::T
end

abstract type InitState end

function default_parameters()
    p = Dict(
        :SRL => 0.4, # Specific Root Length (m g-1)
        :RL0 => 5.0, # Root length at emergence (m)
        :Q10 => 2.1,
        :Rm_base => 0.06,
        :T_ref => 25.0,
        :nitrogen_content => Dict(
            :Stem => 0.005,
            :Internode => 0.005,
            :Leaf => 0.03,
            :Female => 0.01,
            :RootSystem => 0.01,
        ),
        :ini_root_depth => 100.0,
        :potential_area => Dict(
            :leaf_area_first_leaf => 0.0015, # leaf potential area for the first leaf (m2)
            :leaf_area_mature_leaf => 12.0, # leaf potential area for a mature leaf (m2)
            :age_first_mature_leaf => 8 * 365, # age of the first mature leaf (days)
        )
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
    initiation_day=0,
    parameters=default_parameters(),
    model_list=main_models_definition(parameters, nsteps)
)

    scene = MultiScaleTreeGraph.Node(
        1,
        NodeMTG("/", "Scene", 1, 0),
        Dict{Symbol,Any}(
            :models => model_list["Scene"],
        ),
        # type=Scene()
    )

    soil = MultiScaleTreeGraph.Node(
        scene,
        NodeMTG("+", "Soil", 1, 1),
        Dict{Symbol,Any}(
            :models => model_list["Soil"],
        ),
        type=Plant()
    )

    mtg = MultiScaleTreeGraph.Node(
        scene,
        NodeMTG("+", "Plant", 1, 1),
        Dict{Symbol,Any}(
            :models => model_list["Palm"],
            :parameters => parameters,
            :all_models => model_list,
        ),
        type=Plant()
    )

    roots = MultiScaleTreeGraph.Node(
        mtg,
        NodeMTG("+", "RootSystem", 1, 2),
        Dict{Symbol,Any}(
            :initiation_day => initiation_day,
            :depth => parameters[:RL0], # total exploration depth m
            :models => model_list["RootSystem"],
        ),
        type=RootSystem()
    )

    stem = MultiScaleTreeGraph.Node(
        mtg,
        NodeMTG("+", "Stem", 1, 2),
        Dict{Symbol,Any}(
            :initiation_day => initiation_day, # date of initiation / creation
            :models => model_list["Stem"],
        ),
        type=Stem()
    )

    phyto = MultiScaleTreeGraph.Node(stem, NodeMTG("/", "Phytomer", 1, 3),
        Dict{Symbol,Any}(
            :initiation_day => initiation_day, # date of initiation / creation
            :models => model_list["Phytomer"],
        ),
        type=Phytomer(),
    )

    internode = MultiScaleTreeGraph.Node(phyto, NodeMTG("/", "Internode", 1, 4),
        Dict{Symbol,Any}(
            :initiation_day => initiation_day, # date of initiation / creation
            :models => model_list["Internode"],
        ),
        type=Internode(),
    )

    leaf = MultiScaleTreeGraph.Node(internode, NodeMTG("+", "Leaf", 1, 4),
        Dict{Symbol,Any}(
            :initiation_day => initiation_day, # date of initiation / creation
            :models => model_list["Leaf"],
        ),
        type=Leaf(),
    )

    mtg[:phytomer_count] = 1
    mtg[:mtg_node_count] = length(mtg)
    mtg[:last_phytomer] = phyto

    return Palm(scene, initiation_day, parameters)
end