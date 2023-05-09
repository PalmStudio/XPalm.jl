PlantSimEngine.run!(m::Palm, models, status, meteo, constants, extra=nothing)
    # leaves = traverse(mtg, node -> node, symbol = "Leaf")
    m.leaves
end

using MultiScaleTreeGraph, XPalm, Dates
p = Palm()

function cache_nodes(mtg; symbol)
    leaves = traverse(mtg, node -> node, symbol = symbol)
    leaves::Vector{MultiScaleTreeGraph.Node{N,A,Leaf{DataType}}} where {N,A}
end


cache_nodes(mtg, "Leaf")