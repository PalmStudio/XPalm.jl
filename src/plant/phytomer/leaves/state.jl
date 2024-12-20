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
- `rank_phytomers`: rank of the phytomers (multiscale variable)
"""
struct LeafStateModel <: AbstractStateModel end

PlantSimEngine.inputs_(::LeafStateModel) = (maturity=false,)
PlantSimEngine.outputs_(::LeafStateModel) = (state="undetermined", rank_phytomers=[-9999], state_phytomers=["undetermined"],)

function PlantSimEngine.run!(::LeafStateModel, models, status, meteo, constants, extra=nothing)
    # If the phytomer is harvested, the leaf is pruned:
    i = index(status.node) # index of the leaf
    if status.state_phytomers[i] == "Harvested"
        status.state = "Pruned"
        #! This is already done in the InfloStateModel...
    end

    if status.maturity == true && status.state == "undetermined" || index(status.node) == 1
        # Enter here only once, when the leaf is mature and the leaf state was not changed to Opened yet.
        # Or if the leaf is the first leaf of the plant, in which case she is opened already.
        status.state = "Opened"
        # Compute the rank of each phytomer based on the index of the opened leaf:
        # NB: the values are from the oldest to youngest phytomer
        status.rank_phytomers .= index(status.node) .- collect(1:length(status.rank_phytomers))
    end

    return nothing
end