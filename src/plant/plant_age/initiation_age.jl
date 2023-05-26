struct InitiationAgeFromPlantAge <: AbstractInitiation_AgeModel end

PlantSimEngine.inputs_(::InitiationAgeFromPlantAge) = NamedTuple()
PlantSimEngine.outputs_(::InitiationAgeFromPlantAge) = (initiation_age=-9999,)
PlantSimEngine.ObjectDependencyTrait(::Type{<:InitiationAgeFromPlantAge}) = PlantSimEngine.IsObjectDependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:InitiationAgeFromPlantAge}) = PlantSimEngine.IsTimeStepIndependent()

function PlantSimEngine.run!(::InitiationAgeFromPlantAge, models, st, meteo, constants, extra=nothing)
    st.initiation_age = prev_value(st, :initiation_age; default=0.0)
end

# Other method when the model is called with a mtg node:
function PlantSimEngine.run!(::InitiationAgeFromPlantAge, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    st.initiation_age = MultiScaleTreeGraph.ancestors(mtg, :models, symbol="Plant")[1].status[rownumber(st)][:age]
end

