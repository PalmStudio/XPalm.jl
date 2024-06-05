struct LeafStateModel <: AbstractStateModel end

PlantSimEngine.inputs_(::LeafStateModel) = (maturity=false,)
PlantSimEngine.outputs_(::LeafStateModel) = (leaf_state="undetermined",)
PlantSimEngine.dep(::LeafStateModel) = (leaf_rank=AbstractLeaf_RankModel,)

function PlantSimEngine.run!(::LeafStateModel, models, status, meteo, constants, extra=nothing)
    if status.maturity == true && status.leaf_state == "undetermined"
        # Enter here only once, when the leaf is mature and the leaf state was not changed to Opened yet.
        status.leaf_state = "Opened"
        PlantSimEngine.run!(models.leaf_rank, models, status, meteo, constants, extra)
    end
end