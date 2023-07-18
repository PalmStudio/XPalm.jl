struct PhytomerEmission <: AbstractPhytomer_EmissionModel end

PlantSimEngine.inputs_(::PhytomerEmission) = NamedTuple()

PlantSimEngine.outputs_(::PhytomerEmission) = NamedTuple()

"""
    add_phytomer!(palm, initiation_age)

Add a new phytomer to the palm

# Arguments

- `palm`: a Palm
- `initiation_age::Dates.Date`: date of initiation of the phytomer 
"""
function PlantSimEngine.run!(::PhytomerEmission, models, status, meteo, constants, mtg)
    current_step = rownumber(status)
    mtg[:phytomer_count] += 1
    scene = get_root(mtg)
    scene[:mtg_node_count] += 1

    # Create the new phytomer as a child of the last one (younger one):
    phyto = addchild!(
        mtg[:last_phytomer], # parent
        scene[:mtg_node_count], # unique ID
        MultiScaleTreeGraph.NodeMTG("<", "Phytomer", scene[:mtg_node_count], 3), # MTG
        Dict{Symbol,Any}(
            :models => copy(scene[:all_models]["Phytomer"]),
        ), # Attributes
    )

    # Compute the initiation age of the phytomer:
    PlantSimEngine.run!(phyto[:models].models.initiation_age, phyto[:models].models, phyto[:models].status[current_step], meteo, constants, phyto)

    mtg[:last_phytomer] = phyto

    # Add an Internode as its child:
    scene[:mtg_node_count] += 1
    internode = addchild!(
        phyto, # parent
        scene[:mtg_node_count], # unique ID
        MultiScaleTreeGraph.NodeMTG("/", "Internode", mtg[:phytomer_count], 4), # MTG
        Dict{Symbol,Any}(
            :models => copy(scene[:all_models]["Internode"]),
        ), # Attributes
    )

    # Compute the initiation age of the internode:
    PlantSimEngine.run!(internode[:models].models.initiation_age, internode[:models].models, internode[:models].status[current_step], meteo, constants, internode)

    # Add a leaf as its child:
    scene[:mtg_node_count] += 1
    leaf = addchild!(
        internode, # parent
        scene[:mtg_node_count], # unique ID
        MultiScaleTreeGraph.NodeMTG("+", "Leaf", mtg[:phytomer_count], 4), # MTG
        Dict{Symbol,Any}(
            :models => copy(scene[:all_models]["Leaf"]),
        ), # Attributes
    )

    PlantSimEngine.run!(leaf[:models].models.initiation_age, leaf[:models].models, leaf[:models].status[current_step], meteo, constants, leaf)
    PlantSimEngine.run!(internode[:models].models.initiation_age, internode[:models].models, internode[:models].status[current_step], meteo, constants, internode)

    # Compute the leaf_potential_area model over the new leaf:
    PlantSimEngine.run!(leaf[:models].models.leaf_final_potential_area, leaf[:models].models, leaf[:models].status[current_step], meteo, constants, nothing)
    PlantSimEngine.run!(leaf[:models].models.leaf_potential_area, leaf[:models].models, leaf[:models].status[current_step], meteo, constants, nothing)

    # Initialise its leaf area:
    leaf[:models].status[current_step].leaf_area = 0.0
    # And biomass:
    leaf[:models].status[current_step].biomass = 0.0

    # Just for Rm at the begining of the day:
    internode[:models].status[current_step].biomass = 0.0

    # leaf[:models].status[max(1, current_step - 1)].reserve = 0.0
    leaf[:models].status[current_step].reserve = 0.0
    internode[:models].status[current_step].reserve = 0.0
    leaf[:models].status[current_step].carbon_demand = 0.0
    internode[:models].status[current_step].carbon_demand = 0.0

    # Internode:
    PlantSimEngine.run!(internode[:models].models.internode_final_potential_dimensions, internode[:models].models, internode[:models].status[current_step], meteo, constants, nothing)
end