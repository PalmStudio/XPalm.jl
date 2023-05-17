

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