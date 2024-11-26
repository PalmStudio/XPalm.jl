"""
LeafRankModel()

Compute the current rank of the leaf. Change at every new leaf emmision

# Arguments

# Inputs

# Outputs 
- `rank`: leaf rank

"""

struct LeafRankModel <: AbstractLeaf_RankModel end

PlantSimEngine.inputs_(::LeafRankModel) = (rank_phytomers=[0],)
PlantSimEngine.outputs_(::LeafRankModel) = (rank=0,)

function PlantSimEngine.run!(::LeafRankModel, models, status, meteo, constants, extra=nothing)
    i = index(status.node) # index of the leaf
    status.rank = status.rank_phytomers[i] # the rank of the leaf is the rank of its phytomer
end