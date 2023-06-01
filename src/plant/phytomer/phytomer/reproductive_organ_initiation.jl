"""
    ReproductiveOrganInitiation(period_sex_determination)

# Arguments 

- `TT_ini_sex_determination`: start of the `period_sex_determination` (degree days).
- `duration_sex_determination`: duration of the period that determines the inflorescence sex based on the `trophic_status` (degree days).
"""
struct ReproductiveOrganInitiation{T} <: AbstractReproductiveOrganInitiationModel
    period_sex_determination::T
end


PlantSimEngine.inputs_(::ReproductiveOrganInitiation) =
    PlantSimEngine.outputs_(::ReproductiveOrganInitiation) =
        function PlantSimEngine.run!(::ReproductiveOrganInitiation, models, status, meteo, constants, mtg)

        end