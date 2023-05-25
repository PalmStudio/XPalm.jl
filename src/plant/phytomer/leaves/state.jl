struct LeafStateModel <: AbstractStateModel end

PlantSimEngine.inputs_(::LeafStateModel) = (maturity=false,)
PlantSimEngine.outputs_(::LeafStateModel) = NamedTuple()

function PlantSimEngine.run!(::LeafStateModel, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    if status.maturity == true && PlantMeteo.prev_value(status, :maturity, default=false) == false
        mtg.type.state = Opened()
        PlantSimEngine.run!(models.leaf_rank, models, status, meteo, constants, mtg)
    end
end