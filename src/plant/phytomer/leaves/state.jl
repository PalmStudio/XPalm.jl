struct LeafStateModel <: AbstractStateModel end

PlantSimEngine.inputs_(::LeafStateModel) = (maturity=false, leaf_state="undetermined",)
PlantSimEngine.outputs_(::LeafStateModel) = NamedTuple()

function PlantSimEngine.run!(::LeafStateModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    if status.maturity == true && prev_value(status, :maturity, default=false) == false
        status.leaf_state = "Opened"
        PlantSimEngine.run!(models.leaf_rank, models, status, meteo, constants, mtg)
    end
end