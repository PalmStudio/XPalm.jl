@testset "InternodeCarbonDemandModel" begin
    mtg = Palm().mtg
    m = Dict(
        "Plant" => (DailyPlantAgeModel(), DailyDegreeDays(),),
        "Internode" =>
            (
                MultiScaleModel(
                    model=InitiationAgeFromPlantAge(),
                    mapped_variables=[:plant_age => "Plant",],
                ),
                MultiScaleModel(
                    model=DailyDegreeDaysSinceInit(),
                    mapped_variables=[:TEff => "Plant",], # Using TEff computed at plant scale
                ),
                FinalPotentialInternodeDimensionModel(),
                PotentialInternodeDimensionModel(),
                InternodeCarbonDemandModel(300000.0, 1.44),
            )
    )
    vars = Dict{String,Any}("Internode" => (:carbon_demand, :potential_volume, :final_potential_height, :final_potential_radius, :potential_height, :potential_radius, :TT_since_init))
    out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
    df = PlantSimEngine.convert_outputs_2(out, DataFrame)["Internode"]
    total_demand = sum(df.carbon_demand)
    biomass = sum(df.carbon_demand) / 1.44
    @test total_demand ≈ 3664.353671147133
    @test biomass ≈ df.potential_volume[end] * 300000.0 ≈ 2544.6900494077313
end


@testset "LeafCarbonDemandModelPotentialArea" begin
    mtg = Palm().mtg
    m = Dict(
        "Leaf" => (
            LeafCarbonDemandModelPotentialArea(80.0, 1.44, 0.35),
            Status(increment_potential_area=1.0, state="undetermined",)
        )
    )
    vars = Dict{String,Any}("Leaf" => (:carbon_demand,))
    out = run!(mtg, m, meteo[1:2, :], tracked_outputs=vars, executor=SequentialEx())
    df = PlantSimEngine.convert_outputs_2(out, DataFrame)["Leaf"]
    @test df.carbon_demand[1] ≈ 329.14285714285716
    @test df.carbon_demand[1] ≈ 1.0 * (80.0 * 1.44) / 0.35
end