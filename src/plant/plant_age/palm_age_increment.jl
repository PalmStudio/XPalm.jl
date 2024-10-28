"""
    DailyPlantAgeModel(initiation_age)

Plant age model, simply tracks the age of the plant in days.

# Arguments

- `initiation_age`: age of the plant at the start of the simulation (days)

# Returns

- `age`: age of the plant (days)
"""
struct DailyPlantAgeModel{A} <: AbstractPlant_AgeModel
    initiation_age::A
end

function DailyPlantAgeModel(; initiation_age=0)
    DailyPlantAgeModel(initiation_age)
end

PlantSimEngine.inputs_(::DailyPlantAgeModel) = NamedTuple()
PlantSimEngine.outputs_(m::DailyPlantAgeModel) = (plant_age=m.initiation_age,)
PlantSimEngine.ObjectDependencyTrait(::Type{<:DailyPlantAgeModel}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:DailyPlantAgeModel}) = PlantSimEngine.IsTimeStepIndependent()


function PlantSimEngine.run!(m::DailyPlantAgeModel, models, status, meteo, constants, extra=nothing)
    status.plant_age += 1
end