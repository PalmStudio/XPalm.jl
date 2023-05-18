struct PhytomerEmission <: AbstractPhytomer_EmissionModel end

PlantSimEngine.inputs_(::PhytomerEmission) = NamedTuple()

PlantSimEngine.outputs_(::PhytomerEmission) = (
    phytomer_count=-Inf,
    mtg_node_count=-9999,
)

"""
    add_phytomer!(palm, initiation_age)

Add a new phytomer to the palm

# Arguments

- `palm`: a Palm
- `initiation_age::Dates.Date`: date of initiation of the phytomer 
"""
function PlantSimEngine.run!(::PhytomerEmission, models, status, meteo, constants, mtg)
    current_step = PlantMeteo.rownumber(status)
    status.phytomer_count = PlantMeteo.prev_value(
        status,
        :phytomer_count;
        default=mtg[:phytomer_count] # default to the initialisation value
    )
    status.mtg_node_count = PlantMeteo.prev_value(
        status,
        :mtg_node_count;
        default=mtg[:mtg_node_count] # default to the initialisation value
    )

    # Create the new phytomer as a child of the last one (younger one):
    phyto = addchild!(
        mtg[:last_phytomer], # parent
        status.mtg_node_count, # unique ID
        MultiScaleTreeGraph.MutableNodeMTG("<", "Phytomer", status.phytomer_count, 3), # MTG
        Dict{Symbol,Any}(
            :models => mtg[:all_models]["Phytomer"],
        ), # Attributes
        type=Phytomer(),
    )

    # Compute the initiation age of the phytomer:
    PlantSimEngine.run!(phyto[:models].models.plant_age, phyto[:models].models, phyto[:models].status[current_step], meteo, constants, phyto)

    mtg[:last_phytomer] = phyto

    # Add an Internode as its child:
    status.mtg_node_count += 1
    internode = addchild!(
        phyto, # parent
        status.mtg_node_count, # unique ID
        MultiScaleTreeGraph.MutableNodeMTG("/", "Internode", status.phytomer_count, 4), # MTG
        Dict{Symbol,Any}(
            :models => mtg[:all_models]["Internode"],
        ), # Attributes
        type=Internode(),
    )

    # Compute the initiation age of the internode:
    PlantSimEngine.run!(internode[:models].models.plant_age, internode[:models].models, internode[:models].status[current_step], meteo, constants, internode)

    # Add a leaf as its child:
    status.mtg_node_count += 1
    leaf = addchild!(
        internode, # parent
        status.mtg_node_count, # unique ID
        MultiScaleTreeGraph.MutableNodeMTG("+", "Leaf", status.phytomer_count, 4), # MTG
        Dict{Symbol,Any}(
            :models => mtg[:all_models]["Leaf"],
        ), # Attributes
        type=Leaf(),
    )

    PlantSimEngine.run!(leaf[:models].models.plant_age, leaf[:models].models, leaf[:models].status[current_step], meteo, constants, leaf)
end