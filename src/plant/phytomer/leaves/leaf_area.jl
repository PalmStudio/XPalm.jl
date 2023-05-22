struct LeafAreaModel <: AbstractLeaf_AreaModel end

PlantSimEngine.inputs_(::LeafAreaModel) = NamedTuple()
PlantSimEngine.outputs_(::LeafAreaModel) = (leaf_area=-Inf,)

# Applied at the phytomer scale:
function PlantSimEngine.run!(::LeafAreaModel, models, status, meteo, constants, extra=nothing)
    status.leaf_area = status.potential_area
end