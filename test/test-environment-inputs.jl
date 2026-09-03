@testset "declared environment inputs fail before execution" begin
    contracts = (
        (
            model=ET0_BP(),
            fields=(:Tmin, :Tmax, :Rh_min, :Rh_max, :Rg, :Wind, :date),
        ),
        (model=DailyDegreeDays(), fields=(:Tmin, :Tmax)),
        (model=DegreeDaysFTSW(), fields=(:Tmin, :Tmax)),
        (model=Beer(), fields=(:Ri_PAR_f,)),
        (model=RmQ10FixedN(2.1, 0.005, 25.0, 0.5), fields=(:Tmin, :Tmax)),
        (
            model=FTSW(ini_root_depth=300.0),
            fields=(:Precipitations, :Ri_PAR_f),
        ),
        (
            model=FTSW_BP(ini_root_depth=300.0),
            fields=(:Precipitations, :Ri_PAR_f),
        ),
    )

    forcing_value(field) = field == :date ? Date(2000, 1, 1) : 0.0

    for (index, contract) in pairs(contracts)
        @test Tuple(keys(PlantSimEngine.environment_inputs_(contract.model))) ==
              contract.fields

        complete_environment = (;
            (
                field => forcing_value(field)
                for field in contract.fields
            )...,
        )
        specs = Dict(
            :Test => Dict(
                Symbol("environment_probe_", index) => ModelSpec(contract.model),
            ),
        )
        @test PlantSimEngine.validate_environment_inputs(
            specs,
            complete_environment,
        ) === nothing

        for missing_field in contract.fields
            incomplete_environment = (;
                (
                    field => forcing_value(field)
                    for field in contract.fields if field != missing_field
                )...,
            )
            exception = try
                PlantSimEngine.validate_environment_inputs(
                    specs,
                    incomplete_environment,
                )
                nothing
            catch error
                error
            end
            @test exception isa ErrorException
            if exception isa Exception
                message = sprint(showerror, exception)
                @test occursin(
                    "required by model `environment_inputs_`",
                    message,
                )
                @test occursin(string(missing_field), message)
            end
        end
    end

    @test PlantSimEngine.environment_inputs_(DailyDegreeDaysSinceInit()) ==
          NamedTuple()
    @test PlantSimEngine.environment_inputs_(PlantRm()) == NamedTuple()
end
