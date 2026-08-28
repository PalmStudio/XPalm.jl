struct InitiationAgeFromPlantAge <: AbstractInitiation_AgeModel end

PlantSimEngine.inputs_(::InitiationAgeFromPlantAge) = (
    plant_age=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::InitiationAgeFromPlantAge) = (initiation_age=0,)

# This model is called by the phytomer emission model at emission only:
function PlantSimEngine.run!(::InitiationAgeFromPlantAge, st, environment, constants, context=nothing)
    st.initiation_age = copy(st.plant_age) # we use copy so it does not update with plant age then
end
