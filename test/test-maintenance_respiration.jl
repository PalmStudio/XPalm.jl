@testset "Maintenance respiration uses organ dry mass" begin
    model = RmQ10FixedN(2.1, 0.00391, 25.0, 1.0)
    status = Status(biomass=100.0, Rm=0.0)

    PlantSimEngine.run!(
        model,
        status,
        (Tmin=25.0, Tmax=25.0),
        nothing,
    )

    @test status.Rm ≈ 0.391

    living_fraction_model = RmQ10FixedN(2.1, 0.00391, 25.0, 0.25)
    PlantSimEngine.run!(
        living_fraction_model,
        status,
        (Tmin=25.0, Tmax=25.0),
        nothing,
    )
    @test status.Rm ≈ 0.09775
end

@testset "Default maintenance parameters" begin
    parameters = XPalm.default_parameters()["respiration"]

    @test parameters["Leaf"]["Mr"] ≈ 0.00391
    @test parameters["Leaf"]["Mr"] ≈
          0.30 * 0.0083 + 0.30 * 0.0018 + 0.40 * 0.0022
    for organ in ("Leaf", "Internode", "Male", "Female", "RootSystem")
        @test parameters[organ]["P_alive"] == 1.0
    end
end
