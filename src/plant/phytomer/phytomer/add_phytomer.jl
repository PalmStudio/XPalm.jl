
"""
    PhytomerEmission(mtg; phytomer_symbol="Phytomer", internode_symbol="Internode", leaf_symbol="Leaf") <: AbstractPhytomer_EmissionModel
    
A `PhytomerEmission` model, which emits a new phytomer when called. The new phytomer is composed of an internode and a leaf, and is added as a child of the last phytomer.

# Arguments

- `mtg::MultiScaleTreeGraph.Node`: The multiscale tree graph of the plant.
- `phytomer_symbol::String`: The symbol of the phytomer, default to "Phytomer".
- `internode_symbol::String`: The symbol of the internode, default to "Internode".
- `leaf_symbol::String`: The symbol of the leaf, default to "Leaf".

# Inputs

- `graph_node_count::Int`: The number of nodes in the graph.

No other inputs, except for the simulation object (`sim_object`) as the last argument to `run!`.

# Outputs

- `last_phytomer::MultiScaleTreeGraph.Node`: The last phytomer of the palm, takes its values from the struct above as its first value.
- `phytomer_count::Int`: The number of phytomers in the palm.
"""
struct PhytomerEmission <: AbstractPhytomer_EmissionModel
    last_phytomer_init::MultiScaleTreeGraph.Node
    phytomer_count_init::Int
    graph_node_count_init::Int
    phytomer_symbol::String
    internode_symbol::String
    leaf_symbol::String
end

function PhytomerEmission(mtg::MultiScaleTreeGraph.Node; phytomer_symbol="Phytomer", internode_symbol="Internode", leaf_symbol="Leaf")
    phytomers = MultiScaleTreeGraph.descendants(mtg, symbol=phytomer_symbol, self=true)
    PhytomerEmission(phytomers[end], length(phytomers), length(mtg), phytomer_symbol, internode_symbol, leaf_symbol)
end

PlantSimEngine.inputs_(m::PhytomerEmission) = (graph_node_count=m.graph_node_count_init,)
PlantSimEngine.outputs_(m::PhytomerEmission) = (last_phytomer=m.last_phytomer_init, phytomer_count=m.phytomer_count_init,)
PlantSimEngine.dep(::PhytomerEmission) = (
    internode_final_potential_dimensions=AbstractInternode_Final_Potential_DimensionsModel,
    leaf_final_potential_area=AbstractLeaf_Final_Potential_AreaModel,
    leaf_potential_area=AbstractLeaf_Potential_AreaModel,
    initiation_age=AbstractInitiation_AgeModel,
)

"""
    add_phytomer!(palm, initiation_age)

Add a new phytomer to the palm

# Arguments

- `palm`: a Palm
- `initiation_age::Dates.Date`: date of initiation of the phytomer 
"""
function PlantSimEngine.run!(m::PhytomerEmission, models, status, meteo, constants, sim_object)
    status.phytomer_count += 1
    status.graph_node_count += 1
    # Create the new phytomer as a child of the last one (younger one):
    st_phyto = add_organ!(
        status.last_phytomer, # parent, 
        sim_object,  # The simulation object, so we can add the new status 
        "<", m.phytomer_symbol, 3;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}()
    )
    # Compute the initiation age of the phytomer:
    PlantSimEngine.run!(sim_object.models[m.phytomer_symbol].initiation_age, sim_object.models[m.phytomer_symbol], st_phyto, meteo, constants, sim_object)

    status.last_phytomer = st_phyto.node
    # Add an Internode as its child:
    status.graph_node_count += 1

    st_internode = add_organ!(
        st_phyto.node, # parent, 
        sim_object,  # The simulation object, so we can add the new status 
        "/", m.internode_symbol, 4;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}()
    )

    # Compute the initiation age of the internode:
    PlantSimEngine.run!(sim_object.models[m.internode_symbol].initiation_age, sim_object.models[m.internode_symbol], st_internode, meteo, constants, sim_object)
    PlantSimEngine.run!(sim_object.models[m.internode_symbol].internode_final_potential_dimensions, sim_object.models[m.internode_symbol], st_internode, meteo, constants, sim_object)

    # Add a leaf as its child:
    status.graph_node_count += 1

    st_leaf = add_organ!(
        st_internode.node, # parent, 
        sim_object,  # The simulation object, so we can add the new status 
        "+", m.leaf_symbol, 4;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}()
    )

    PlantSimEngine.run!(sim_object.models[m.leaf_symbol].initiation_age, sim_object.models[m.leaf_symbol], st_leaf, meteo, constants, sim_object)

    # Compute the leaf_potential_area model over the new leaf:
    PlantSimEngine.run!(sim_object.models[m.leaf_symbol].leaf_final_potential_area, sim_object.models[m.leaf_symbol], st_leaf, meteo, constants, sim_object)
    PlantSimEngine.run!(sim_object.models[m.leaf_symbol].leaf_potential_area, sim_object.models[m.leaf_symbol], st_leaf, meteo, constants, sim_object)

    return nothing
end