@testset "InternodeCarbonDemandModel" begin
    mtg = Palm().mtg
    m = Dict(
        "Plant" => (XPalm.DailyPlantAgeModel(), XPalm.DailyDegreeDays(),),
        "Internode" =>
            (
                MultiScaleModel(
                    model=XPalm.InitiationAgeFromPlantAge(),
                    mapping=[:plant_age => "Plant",],
                ),
                MultiScaleModel(
                    model=XPalm.DailyDegreeDaysSinceInit(),
                    mapping=[:TEff => "Plant",], # Using TEff computed at plant scale
                ),
                XPalm.FinalPotentialInternodeDimensionModel(),
                XPalm.PotentialInternodeDimensionModel(),
                XPalm.InternodeCarbonDemandModel(300000.0, 1.44),
            )
    )
    vars = Dict{String,Any}("Internode" => (:carbon_demand, :potential_volume, :final_potential_height, :final_potential_radius, :potential_height, :potential_radius, :TT_since_init))
    out = run!(mtg, m, meteo, outputs=vars, executor=SequentialEx())
    df = outputs(out, DataFrame)
    total_demand = sum(df.carbon_demand)
    biomass = sum(df.carbon_demand) / 1.44
    @test total_demand ≈ 133.4260422797521
    @test biomass ≈ df.potential_volume[end] * 300000.0 ≈ 92.6569738053834
end


@testset "LeafCarbonDemandModelPotentialArea" begin
    mtg = Palm().mtg
    m = Dict(
        "Leaf" => (
            XPalm.LeafCarbonDemandModelPotentialArea(80.0, 1.44, 0.35),
            Status(increment_potential_area=1.0, state="undetermined",)
        )
    )
    vars = Dict{String,Any}("Leaf" => (:carbon_demand,))
    out = run!(mtg, m, meteo[1:2, :], outputs=vars, executor=SequentialEx())
    df = outputs(out, DataFrame)
    @test df.carbon_demand[1] ≈ 329.14285714285716
    @test df.carbon_demand[1] ≈ 1.0 * (80.0 * 1.44) / 0.35
end