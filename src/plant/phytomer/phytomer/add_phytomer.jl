"""
    PhytomerEmission(mtg; phytomer_symbol=:Phytomer, internode_symbol=:Internode, leaf_symbol=:Leaf) <: AbstractPhytomer_EmissionModel
    
A `PhytomerEmission` model, which emits a new phytomer when called. The new phytomer is composed of an internode and a leaf, and is added as a child of the last phytomer.

# Arguments

- `mtg::MultiScaleTreeGraph.Node`: The multiscale tree graph of the plant.
- `phytomer_symbol::Symbol`: The symbol of the phytomer, default to `:Phytomer`.
- `internode_symbol::Symbol`: The symbol of the internode, default to `:Internode`.
- `leaf_symbol::Symbol`: The symbol of the leaf, default to `:Leaf`.

# Inputs

- `graph_node_count::Int`: The number of nodes in the graph.

No other inputs; the execution context is supplied as the last argument to `run!`.

# Outputs

- `last_phytomer::PlantSimEngine.ObjectId`: Stable identity of the last phytomer
  of the palm.
- `phytomer_count::Int`: The number of phytomers in the palm.
"""
struct PhytomerEmission <: AbstractPhytomer_EmissionModel
    last_phytomer_init::PlantSimEngine.ObjectId
    phytomer_count_init::Int
    graph_node_count_init::Int
    phytomer_symbol::Symbol
    internode_symbol::Symbol
    leaf_symbol::Symbol
end

function PhytomerEmission(mtg::MultiScaleTreeGraph.Node; phytomer_symbol=:Phytomer, internode_symbol=:Internode, leaf_symbol=:Leaf)
    phytomers = MultiScaleTreeGraph.descendants(mtg, symbol=phytomer_symbol, self=true)
    PhytomerEmission(
        PlantSimEngine.ObjectId(MultiScaleTreeGraph.node_id(phytomers[end])),
        length(phytomers),
        length(mtg),
        phytomer_symbol,
        internode_symbol,
        leaf_symbol,
    )
end

PlantSimEngine.inputs_(m::PhytomerEmission) = (
    graph_node_count=PlantSimEngine.Default(m.graph_node_count_init),
)
PlantSimEngine.outputs_(m::PhytomerEmission) = (last_phytomer=m.last_phytomer_init, phytomer_count=m.phytomer_count_init,)
"""
    add_phytomer!(palm, initiation_age)

Add a new phytomer to the palm

# Arguments

- `palm`: a Palm
- `initiation_age::Dates.Date`: date of initiation of the phytomer 
"""
function PlantSimEngine.run!(m::PhytomerEmission, status, environment, constants, context)
    status.phytomer_count += 1
    status.graph_node_count += 1
    plant_age = status.plant_age
    # Create the new phytomer as a child of the last one (younger one):
    last_phytomer = PlantSimEngine.source_node(
        context,
        status.last_phytomer,
    )
    st_phyto = PlantSimEngine.add_organ!(
        last_phytomer, # parent,
        context,
        :<,
        m.phytomer_symbol,
        3;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}(),
        initial_status=(plant_age=plant_age, initiation_age=plant_age),
    )

    phytomer_id = PlantSimEngine.object_id(context, st_phyto)
    status.last_phytomer = phytomer_id
    # Add an Internode as its child:
    status.graph_node_count += 1

    st_internode = PlantSimEngine.add_organ!(
        PlantSimEngine.source_node(context, phytomer_id), # parent,
        context,
        :/,
        m.internode_symbol,
        4;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}(),
        initial_status=(plant_age=plant_age, initiation_age=plant_age),
    )
    internode_id = PlantSimEngine.object_id(context, st_internode)

    # Add a leaf as its child:
    status.graph_node_count += 1

    st_leaf = PlantSimEngine.add_organ!(
        PlantSimEngine.source_node(context, internode_id), # parent,
        context,
        :+,
        m.leaf_symbol,
        4;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}(),
        initial_status=(plant_age=plant_age, initiation_age=plant_age),
    )
    leaf_id = PlantSimEngine.object_id(context, st_leaf)

    PlantSimEngine.run_call!(
        context,
        :phytomer_initiation_age;
        objects=phytomer_id,
    )
    PlantSimEngine.run_call!(
        context,
        :internode_initiation_age;
        objects=internode_id,
    )
    PlantSimEngine.run_call!(
        context,
        :internode_final_potential_dimensions;
        objects=internode_id,
    )
    PlantSimEngine.run_call!(
        context,
        :internode_initial_maintenance_respiration;
        objects=internode_id,
    )
    PlantSimEngine.run_call!(
        context,
        :leaf_initiation_age;
        objects=leaf_id,
    )
    PlantSimEngine.run_call!(
        context,
        :leaf_final_potential_area;
        objects=leaf_id,
    )
    PlantSimEngine.run_call!(
        context,
        :leaf_initial_maintenance_respiration;
        objects=leaf_id,
    )

    return nothing
end
