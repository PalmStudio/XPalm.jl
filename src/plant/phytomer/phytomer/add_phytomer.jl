struct PhytomerEmission <: AbstractPhytomer_EmissionModel end

PlantSimEngine.inputs_(::PhytomerEmission) = NamedTuple()
PlantSimEngine.outputs_(::PhytomerEmission) = NamedTuple()
# PlantSimEngine.dep(::PhytomerEmission) = (phytomer_count=AbstractPhytomer_CountModel,)
PlantSimEngine.dep(::PhytomerEmission) = (
    initiation_age=AbstractInitiation_AgeModel,
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
function PlantSimEngine.run!(::PhytomerEmission, models, status, meteo, constants, sim_object)
    plant_node = status.node

    # PlantSimEngine.run!(sim_object.models["Phytomer"].phytomer_count, sim_object.models["Phytomer"], status, meteo, constants, sim_object)
    plant_node[:phytomer_count] += 1

    scene = MultiScaleTreeGraph.get_root(plant_node)

    # PlantSimEngine.run!(sim_object.models["Scene"].graph_node_count, sim_object.models["Scene"], sim_object.statuses["Scene"][1], meteo, constants, sim_object)
    scene[:mtg_node_count] += 1

    # Create the new phytomer as a child of the last one (younger one):
    st_phyto = add_organ!(
        plant_node[:last_phytomer], # parent, 
        sim_object,  # The simulation object, so we can add the new status 
        "<", "Phytomer", 3;
        index=plant_node[:phytomer_count],
        id=scene[:mtg_node_count],
        attributes=Dict{Symbol,Any}()
    )

    # Compute the initiation age of the phytomer:
    PlantSimEngine.run!(sim_object.models["Phytomer"].initiation_age, sim_object.models["Phytomer"], st_phyto, meteo, constants, sim_object)

    plant_node[:last_phytomer] = st_phyto.node

    # Add an Internode as its child:
    scene[:mtg_node_count] += 1
    # PlantSimEngine.run!(sim_object.models["Scene"].mtg_node_count, sim_object.models["Scene"], sim_object.statuses["Scene"][1], meteo, constants, sim_object)

    st_internode = add_organ!(
        st_phyto.node, # parent, 
        sim_object,  # The simulation object, so we can add the new status 
        "/", "Internode", 4;
        index=plant_node[:phytomer_count],
        id=scene[:mtg_node_count],
        attributes=Dict{Symbol,Any}()
    )

    # Compute the initiation age of the internode:
    PlantSimEngine.run!(sim_object.models["Internode"].initiation_age, sim_object.models["Internode"], st_internode, meteo, constants, sim_object)
    PlantSimEngine.run!(sim_object.models["Internode"].internode_final_potential_dimensions, sim_object.models["Internode"], st_internode, meteo, constants, sim_object)

    # Add a leaf as its child:
    scene[:mtg_node_count] += 1
    # PlantSimEngine.run!(sim_object.models["Scene"].mtg_node_count, sim_object.models["Scene"], sim_object.statuses["Scene"][1], meteo, constants, sim_object)

    st_leaf = add_organ!(
        st_internode.node, # parent, 
        sim_object,  # The simulation object, so we can add the new status 
        "+", "Leaf", 4;
        index=plant_node[:phytomer_count],
        id=scene[:mtg_node_count],
        attributes=Dict{Symbol,Any}()
    )

    # Compute the leaf_potential_area model over the new leaf:
    PlantSimEngine.run!(sim_object.models["Internode"].initiation_age, sim_object.models["Leaf"], st_leaf, meteo, constants, sim_object)
    PlantSimEngine.run!(sim_object.models["Leaf"].leaf_final_potential_area, sim_object.models["Leaf"], st_leaf, meteo, constants, sim_object)
    PlantSimEngine.run!(sim_object.models["Leaf"].leaf_potential_area, sim_object.models["Leaf"], st_leaf, meteo, constants, sim_object)

    # Initialise its leaf area:
    # st_leaf.leaf_area = 0.0
    # And biomass:
    # st_leaf.biomass = 0.0

    # Just for Rm at the begining of the day:
    # st_internode.biomass = 0.0

    # leaf[:models].status[max(1, current_step - 1)].reserve = 0.0
    # st_leaf.reserve = 0.0
    # st_internode.reserve = 0.0
    # st_leaf.carbon_demand = 0.0
    # st_internode.carbon_demand = 0.0
end