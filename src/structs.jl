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
mutable struct Palm
    mtg::MultiScaleTreeGraph.Node
    initiation_date::Dates.Date
    phytomer_count::Int
    mtg_node_count::Int
end

abstract type InitState end

function Palm(initiation_date=Dates.Date(Dates.now()))
    mtg = MultiScaleTreeGraph.Node(
        1,
        NodeMTG("/", "Palm", 1, 1),
        Dict{Symbol,Any}()
    )

    roots = MultiScaleTreeGraph.Node(
        mtg,
        NodeMTG("+", "RootSystem", 1, 2),
        Dict{Symbol,Any}(
            :organ => RootSystem(),
            :initiation_date => initiation_date,
        )
    )

    stem = MultiScaleTreeGraph.Node(
        mtg,
        NodeMTG("+", "Stem", 1, 2),
        Dict{Symbol,Any}(
            :organ => Stem(),
            :initiation_date => initiation_date, # date of initiation / creation
        )
    )

    phyto = MultiScaleTreeGraph.Node(stem, NodeMTG("/", "Phytomer", 1, 3),
        Dict{Symbol,Any}(
            :organ => Phytomer(),
            :initiation_date => initiation_date, # date of initiation / creation
        )
    )

    internode = MultiScaleTreeGraph.Node(phyto, NodeMTG("/", "Internode", 1, 4),
        Dict{Symbol,Any}(
            :organ => Internode(),
            :initiation_date => initiation_date, # date of initiation / creation
        )
    )

    leaf = MultiScaleTreeGraph.Node(internode, NodeMTG("+", "Leaf", 1, 4),
        Dict{Symbol,Any}(
            :organ => Leaf(),
            :initiation_date => initiation_date, # date of initiation / creation
        )
    )

    return Palm(mtg, initiation_date, 1, 6)
end

abstract type Organ end

struct RootSystem <: Organ end
struct Stem <: Organ end

"""
    Phytomer(state)

A phytomer
"""
struct Phytomer <: Organ end

"""
    InternodeState

Defines the physiological state of the internode.
"""
abstract type InternodeState end

struct Growing <: InternodeState end
struct Snag <: InternodeState end

"""
    Internode(state)

An internode, which has a state of type [`InternodeState`](@ref) that can be either:

- `Growing`: has both growth and maintenance respiration
- `Snag`: has maintenance respiration only, and no leaf 
or reproductive organs
"""
struct Internode{S} <: Organ where {S<:InternodeState}
    state::S
end

Internode() = Internode(Growing)

abstract type LeafState end

struct Initiation <: LeafState end
struct Spear <: LeafState end
struct Opened <: LeafState end
struct Pruned <: LeafState end
struct Scenescent <: LeafState end

"""
    Leaf(state)

A leaf, which has a state of type [`LeafState`](@ref) that can be either:

- `Initiation`: in initiation phase (cell division until begining of elongation)
- `Spear`: spear phase, almost fully developped, but leaflets are not yet deployed
- `Opened`: deployed and photosynthetically active
- `Pruned`: dead and removed from the plant
- `Scenescent`: dead but still on the plant
"""
struct Leaf{S} <: Organ where {S<:LeafState}
    state::S
end
Leaf() = Leaf(Initiation)

abstract type ReproductiveOrgan <: Organ end

"""
    Male(state)

A male inflorescence, which has a state that can be either:

- `:initiated`: in initiation phase (cell division)
- `:aborted`
- `:flowering`
- `:scenescent`: dead but still on the plant
- `:pruned`: removed from the plant
"""
struct Male <: ReproductiveOrgan
    state::String
end

"""
    Female(state)

A female inflorescence, which has a state that can be either:

- `:initiated`: in initiation phase (cell division)
- `:aborted`
- `:flowering`
- `:bunch`: the bunch of fruits is developping
- `:oleosynthesis`: the inflorescence is in the process of oleosynthesis
- `:scenescent`: dead but still on the plant
- `:pruned`: removed from the plant (*e.g.* harvested)
"""
struct Female <: ReproductiveOrgan
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

