"""
    LeafStateModel()

Give the state of the leaf 

# Arguments

None

# Inputs

- `maturity`: a leaf is mature when it reaches its final length
- `state_phytomers`: state of the phytomers (multiscale variable)

# Outputs 

- `state`: leaf state ("undetermined", "Opened", "Pruned")
- `rank_leaves`: rank of all leaves
"""
struct LeafStateModel <: AbstractStateModel end

PlantSimEngine.inputs_(::LeafStateModel) = (maturity=false, state_phytomers=["undetermined"])
PlantSimEngine.outputs_(::LeafStateModel) = (state="undetermined", rank=-9999, rank_leaves=[-9999])

function PlantSimEngine.run!(::LeafStateModel, models, status, meteo, constants, extra=nothing)
    # If the phytomer is harvested, the leaf is pruned:
    i = index(status.node) # index of the leaf
    if status.state_phytomers[i] == "Harvested"
        status.state = "Pruned"
        #! This is already done in the InfloStateModel...
    end

    if (status.maturity == true || index(status.node) == 1) && status.state == "undetermined"
        # Enter here only once, when the leaf is mature and the leaf state was not changed to Opened yet.
        # Or if the leaf is the first leaf of the plant (and also with status still undetermined), in which case she is opened already.
        status.state = "Opened"
        status.rank = 1 # When a leaf open, it becomes the leaf at rank 1, and all the older leaves are shifted by one rank.
        # Compute the rank of each phytomer based on the index of the opened leaf:
        # NB: the values are from the oldest to youngest phytomer
        status.rank_leaves .= (index(status.node) + 1) .- collect(1:length(status.rank_leaves))
    end

    return nothing
end