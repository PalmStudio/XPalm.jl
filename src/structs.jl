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

"""
    Palm(mtg, phytomer_count, max_rank, node_count)
    Palm()

Create a new Palm. The maximum rank is used to determine how many living phytomers (i.e. leaves) are there
on the Palm.

`Palm()` (without arguments) creates a new Palm with a single phytomer, one leaf, and a Root system.

# Arguments
- `mtg`: a MTG object
- `phytomer_count`: total number of phytomers emitted by the Palm since germination, *i.e.* physiological age
- `mtg_node_count`: total number of nodes in the MTG (used to determine the unique ID)
"""
mutable struct Palm{T} <: Organ
    mtg::MultiScaleTreeGraph.Node
    initiation_date::Dates.Date
    phytomer_count::Int
    mtg_node_count::Int
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

function Palm(
    initiation_date=Dates.Date(Dates.now()),
    parameters=default_parameters(),
    model_list=main_models_definition(parameters)
)
    mtg = MultiScaleTreeGraph.Node(
        1,
        NodeMTG("/", "Plant", 1, 1),
        Dict{Symbol,Any}(
            :models => model_list["Palm"],
        ),
        type=Plant()
    )

    roots = MultiScaleTreeGraph.Node(
        mtg,
        NodeMTG("+", "RootSystem", 1, 2),
        Dict{Symbol,Any}(
            :initiation_date => initiation_date,
            :depth => parameters[:RL0], # total exploration depth m
            :models => model_list[:RootSystem],
        ),
        type=RootSystem()
    )

    stem = MultiScaleTreeGraph.Node(
        mtg,
        NodeMTG("+", "Stem", 1, 2),
        Dict{Symbol,Any}(
            :initiation_date => initiation_date, # date of initiation / creation
            :models => model_list[:Stem],
        ),
        type=Stem()
    )

    phyto = MultiScaleTreeGraph.Node(stem, NodeMTG("/", "Phytomer", 1, 3),
        Dict{Symbol,Any}(
            :initiation_date => initiation_date, # date of initiation / creation
            :models => model_list["Phytomer"],
        ),
        type=Phytomer(),
    )

    internode = MultiScaleTreeGraph.Node(phyto, NodeMTG("/", "Internode", 1, 4),
        Dict{Symbol,Any}(
            :initiation_date => initiation_date, # date of initiation / creation
            :models => model_list[:Internode],
        ),
        type=Internode(),
    )

    leaf = MultiScaleTreeGraph.Node(internode, NodeMTG("+", "Leaf", 1, 4),
        Dict{Symbol,Any}(
            :initiation_date => initiation_date, # date of initiation / creation
            :models => model_list[:Leaf],
        ),
        type=Leaf(),
    )

    return Palm(mtg, initiation_date, 1, 6, parameters)
end

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

