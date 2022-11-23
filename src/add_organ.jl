"""
    add_phytomer!(palm, initiation_date)

Add a new phytomer to the palm

# Arguments

- `palm`: a Palm
- `initiation_date::Dates.Date`: date of initiation of the phytomer 
"""
function add_phytomer!(palm::Palm, initiation_date::Dates.Date)
    #! Get the last phytomer in the mtg:
    #! last_phytomer = MultiScaleTreeGraph.traverse(palm.mtg...)

    palm.phytomer_count += 1
    palm.mtg_node_count += 1

    # Create the new phytomer as a child of the last one (younger one):
    MultiScaleTreeGraph.addchild!(
        last_phytomer, # parent
        palm.phytomer_count, # unique ID
        MultiScaleTreeGraph.MutableNodeMTG("<", "Phytomer", palm.phytomer_count, 2), # MTG
        Dict{Symbol,Any}(
            :organ => Phytomer(),
            :initiation_date => initiation_date, # date of initiation / creation
        ) # Attributes
    )


    # Add a Internode as its child:
    palm.mtg_node_count += 1
    MultiScaleTreeGraph.addchild!(
        last_phytomer[1], # parent
        palm.mtg_node_count, # unique ID
        MultiScaleTreeGraph.MutableNodeMTG("/", "Internode", palm.phytomer_count, 3), # MTG
        Dict{Symbol,Any}(
            :organ => Internode()
        ) # Attributes
    )

    # Add a Internode as its child:
    palm.mtg_node_count += 1
    MultiScaleTreeGraph.addchild!(
        #! Pass the Internode here, not the phytomer: 
        last_phytomer[1], # parent
        palm.mtg_node_count, # unique ID
        MultiScaleTreeGraph.MutableNodeMTG("+", "Leaf", palm.phytomer_count, 3), # MTG
        Dict{Symbol,Any}(
            :organ => Phytomer()
        ) # Attributes
    )
end

"""

Determine the sex of the reproductive organ based on the trophic state
of the palm tree on x last days
"""
function determine_sex(pmin, pmax, pref)

end


"""

ex: `add_reproductive_organ(node[:organ], node)`
"""
function add_reproductive_organ(::Phytomer, node)
    #! if something  add_female else add_male
    #! add
end

function add_reproductive_organ(x, node)
    error("Cannot add a reproductive organ to an organ that is not a phytomer")
end


function add_female!(node::MultiScaleTreeGraph.Node)

end

function add_male!(phyt::Phytomer)

end