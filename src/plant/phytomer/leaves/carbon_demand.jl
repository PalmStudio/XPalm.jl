struct CarbonDemandModel <: AbstractCarbon_DemandModel

end

PlantSimEngine.inputs_(::CarbonDemandModel) = NamedTuple()
PlantSimEngine.outputs_(::CarbonDemandModel) = NamedTuple()

function PlantSimEngine.run!(::CarbonDemandModel, models, status, meteo, constants, extra=nothing)


end