"""
    GraphNodeCount(graph_node_count_ini=0)
    
Stores the number of nodes in the graph.

# Arguments

- `graph_node_count_ini`: the initial number of nodes in the graph.

# Outputs

- `graph_node_count`: the number of nodes in the graph.

# Details

This model does nothing. It is just used to define the value of the graph's node count so it exists in the `status`
of the organ.

The node cound should be updated by the models that create new organs at the time-step of organ emission.
"""
struct GraphNodeCount{T} <: AbstractPhytomer_CountModel
    graph_node_count_ini::T
end

PlantSimEngine.inputs_(::GraphNodeCount) = NamedTuple()
PlantSimEngine.outputs_(m::GraphNodeCount) = (graph_node_count=m.graph_node_count_ini,)

# This model is called by the phytomer emission model at emission only:
@inline function PlantSimEngine.run!(::GraphNodeCount, models, st, meteo, constants, extra=nothing)
    nothing # This is called only at the emission of a phytomer
end

