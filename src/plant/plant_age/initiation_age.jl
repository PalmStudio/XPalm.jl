struct InitiationAgeFromPlantAge <: AbstractInitiation_AgeModel end

PlantSimEngine.inputs_(::InitiationAgeFromPlantAge) = (plant_age=-9999,)
PlantSimEngine.outputs_(::InitiationAgeFromPlantAge) = (initiation_age=0,)
PlantSimEngine.ObjectDependencyTrait(::Type{<:InitiationAgeFromPlantAge}) = PlantSimEngine.IsObjectDependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:InitiationAgeFromPlantAge}) = PlantSimEngine.IsTimeStepIndependent()

# This model is called by the phytomer emission model at emission only:
function PlantSimEngine.run!(::InitiationAgeFromPlantAge, models, st, meteo, constants, extra=nothing)
    st.initiation_age = copy(st.plant_age) # we use copy so it does not update with plant age then
end

