"""
    Palm(mtg, phytomer_count, max_rank, node_count)

Create a new Palm. The maximum rank is used to determine how many living phytomers (i.e. leaves) are there
on the Palm.

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

Palm() = Palm(
    MultiScaleTreeGraph.Node(1, MultiScaleTreeGraph.NodeMTG("/", "Palm", 1, 1), Dict{Symbol,Any}()),
    0,
)

abstract type Organ end

"""
    Phytomer(state)

A phytomer
"""
struct Phytomer <: Organ end

"""
    Internode(state)

An internode, which has a state that can be either:

- `:growing`: has both growth and maintenance respiration
- `:active`: has maintenance demand only, and bears a lead and/or 
a reproductive organ
- `:snag`: has maintenance respiration only, and no leaf 
or reproductive organs
"""
struct Internode <: Organ
    state::String
end

"""
    Leaf(state)

A leaf, which has a state that can be either:

- `:initiation`: in initiation phase (cell division until begining of elongation)
- `:spear`: spear phase, almost fully developped, but leaflets are not yet deployed
- `:opened`: deployed and photosynthetically active
- `:pruned`: dead and removed from the plant
- `:scenescent`: dead but still on the plant
"""
struct Leaf <: Organ
    state::String
end

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

