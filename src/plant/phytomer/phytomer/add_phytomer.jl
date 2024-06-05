
"""
    PhytomerEmission(internode_symbol,leaf_symbol) <: AbstractPhytomer_EmissionModel
    PhytomerEmission()

A `PhytomerEmission` model, which emits a new phytomer.

# Fields

- `internode_symbol::String="Internode"`: The string defining the internode MTG symbol.

"""
struct PhytomerEmission <: AbstractPhytomer_EmissionModel
    phytomer_symbol::String
    internode_symbol::String
    leaf_symbol::String
end

PhytomerEmission() = PhytomerEmission("Phytomer", "Internode", "Leaf")


PlantSimEngine.inputs_(::PhytomerEmission) = (plant_age=-9999, last_phytomer=MultiScaleTreeGraph.Node(NodeMTG("/", "Internode", 1, 2)), graph_node_count=0,)
PlantSimEngine.outputs_(::PhytomerEmission) = (initiation_age=[-9999], phytomer_count=0)
# PlantSimEngine.dep(::PhytomerEmission) = (phytomer_count=AbstractPhytomer_CountModel,)
PlantSimEngine.dep(::PhytomerEmission) = (
    internode_final_potential_dimensions=AbstractInternode_Final_Potential_DimensionsModel,
    leaf_final_potential_area=AbstractLeaf_Final_Potential_AreaModel,
    leaf_potential_area=AbstractLeaf_Potential_AreaModel,
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

    plant_age = copy(status.plant_age)

    # Compute the initiation age of the phytomer:
    st_phyto.initiation_age = plant_age
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
    st_internode.initiation_age = plant_age
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

    st_leaf.initiation_age = plant_age

    # Compute the leaf_potential_area model over the new leaf:
    PlantSimEngine.run!(sim_object.models[m.leaf_symbol].leaf_final_potential_area, sim_object.models[m.leaf_symbol], st_leaf, meteo, constants, sim_object)
    PlantSimEngine.run!(sim_object.models[m.leaf_symbol].leaf_potential_area, sim_object.models[m.leaf_symbol], st_leaf, meteo, constants, sim_object)

    return nothing
end