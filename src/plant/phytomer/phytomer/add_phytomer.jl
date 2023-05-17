struct PhytomerEmission <: AbstractPhytomer_EmissionModel end

PlantSimEngine.inputs_(::Type{PhytomerEmission}) = (
    initiation_day=-9999,
    mtg_node_count=-9999,
    phytomer_count=-9999,
)

"""
    add_phytomer!(palm, initiation_day)

Add a new phytomer to the palm

# Arguments

- `palm`: a Palm
- `initiation_day::Dates.Date`: date of initiation of the phytomer 
"""
function PlantSimEngine.run!(::PhytomerEmission, models, status, meteo, constants, mtg)
    status.phytomer_count += 1
    status.mtg_node_count += 1

    # Create the new phytomer as a child of the last one (younger one):
    phyto = addchild!(
        mtg[:last_phytomer], # parent
        status.mtg_node_count, # unique ID
        MutableNodeMTG("<", "Phytomer", status.phytomer_count, 3), # MTG
        Dict{Symbol,Any}(
            :models => mtg[:all_models]["Phytomer"],
        ), # Attributes
        type=Phytomer(),
    )
    status(phyto, :initiation_day, status.initiation_day)

    mtg[:last_phytomer] = phyto

    # Add an Internode as its child:
    status.mtg_node_count += 1
    internode = addchild!(
        phyto, # parent
        status.mtg_node_count, # unique ID
        MutableNodeMTG("/", "Internode", status.phytomer_count, 4), # MTG
        Dict{Symbol,Any}(
            :models => mtg[:all_models]["Internode"],
        ), # Attributes
        type=Internode(),
    )

    status(internode, :initiation_day, status.initiation_day)

    # Add a leaf as its child:
    status.mtg_node_count += 1
    leaf = addchild!(
        internode, # parent
        status.mtg_node_count, # unique ID
        MutableNodeMTG("+", "Leaf", status.phytomer_count, 4), # MTG
        Dict{Symbol,Any}(
            :models => mtg[:all_models]["Leaf"],
        ), # Attributes
        type=Leaf(),
    )

    status(leaf, :initiation_day, status.initiation_day)
end