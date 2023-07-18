# struct ReproductiveDevelopment{T} <: AbstractReproductive_DevelopmentModel
#     age_max_coefficient::T
#     min_coefficient::T
#     max_coefficient::T
# end

# function ReproductiveDevelopment(age_max_coefficient::T, min_coefficient::T) where {T}
#     ReproductiveDevelopment(age_max_coefficient, min_coefficient, one(min_coefficient))
# end

# PlantSimEngine.inputs_(::ReproductiveDevelopment) = (initiation_age=-9999,)

# PlantSimEngine.outputs_(::ReproductiveDevelopment) = (final_reproductive_organ_dimension=-Inf,)

# function PlantSimEngine.run!(m::ReproductiveDevelopment, models, status, meteo, constants, mtg)
#     status.final_reproductive_organ_dimension =
#         age_relative_value(
#             status.initiation_age,
#             0.0,
#             m.age_max_coefficient,
#             m.min_coefficient,
#             m.max_coefficient
#         )
# end