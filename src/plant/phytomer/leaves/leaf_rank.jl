"""
LeafRankModel()

Compute the current rank of the leaf. Change at every new leaf emmision

# Arguments

# Inputs

# Outputs 
- `rank`: leaf rank

"""

struct LeafRankModel <: AbstractLeaf_RankModel end

PlantSimEngine.inputs_(::LeafRankModel) = NamedTuple()
PlantSimEngine.outputs_(::LeafRankModel) = (rank=[0],)

function PlantSimEngine.run!(::LeafRankModel, models, status, meteo, constants, extra=nothing)
    status.rank .+= 1 # We increase the rank of all phytomers here (this is supposed to be a multiscale model, with rank coming from the phytomers)
end