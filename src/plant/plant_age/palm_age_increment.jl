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
PlantSimEngine.outputs_(::DailyPlantAgeModel) = (age=-9999,)
PlantSimEngine.ObjectDependencyTrait(::Type{<:DailyPlantAgeModel}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:DailyPlantAgeModel}) = PlantSimEngine.IsTimeStepIndependent()


function PlantSimEngine.run!(m::DailyPlantAgeModel, models, status, meteo, constants, extra=nothing)
    status.age = PlantMeteo.rownumber(status) + m.initiation_age
    # could also be written as (TODO: check which is faster):
    # status.age = prev_value(status, :age; default=m.initiation_age)
end

# Other method when the model is called with a mtg node:
function PlantSimEngine.run!(m::DailyPlantAgeModel, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    st.age = MultiScaleTreeGraph.ancestors(mtg, :models, symbol="Plant")[1].status[PlantMeteo.rownumber(st)][:age]
end