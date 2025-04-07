@testset "InternodeBiomass" begin
    m = ModelList(
        InternodeBiomass(),
        status=(carbon_allocation=10.0, biomass=0.0)
    )

    outputs = run!(m, executor=SequentialEx())
    @test outputs[:biomass][1] ≈ 10.0 / 1.44
end

@testset "MaleBiomass" begin
    @testset "Continuous growth" begin
        mtg = Palm().mtg
        MultiScaleTreeGraph.Node(get_node(mtg, 7), NodeMTG("+", "Male", 1, 4))
        m = Dict(
            "Male" => (
                MaleBiomass(),
                Status(carbon_allocation=10.0, state="undetermined")
            )
        )
        vars = Dict{String,Any}("Male" => (:biomass, :litter_male))
        out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
        df = PlantSimEngine.convert_outputs_2(out, DataFrame)["Male"]
        @test df.biomass[1] ≈ 6.944444444444445
        @test df.biomass[end] ≈ 28888.888888891193
        @test df.litter_male[end] ≈ 0.0 # no senescence
    end

    @testset "Harvested" begin
        mtg = Palm().mtg
        MultiScaleTreeGraph.Node(get_node(mtg, 7), NodeMTG("+", "Male", 1, 4))
        m = Dict(
            "Male" => (
                MaleBiomass(),
                Status(carbon_allocation=0.0, state="Harvested", biomass=10.0)
            )
        )
        vars = Dict{String,Any}("Male" => (:biomass, :litter_male))
        out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
        df = PlantSimEngine.convert_outputs_2(out, DataFrame)["Male"]
        @test df.biomass == zeros(length(df.biomass))
        @test df.litter_male[1] == 10.0
        @test df.litter_male[2:end] == zeros(length(df.biomass) - 1)
    end

    @testset "Aborted" begin
        mtg = Palm().mtg
        MultiScaleTreeGraph.Node(get_node(mtg, 7), NodeMTG("+", "Male", 1, 4))
        m = Dict(
            "Male" => (
                MaleBiomass(),
                Status(carbon_allocation=10.0, state="Aborted", biomass=0.0)
            )
        )

        vars = Dict{String,Any}("Male" => (:biomass, :litter_male))
        out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
        df = PlantSimEngine.convert_outputs_2(out, DataFrame)["Male"]
        @test df.biomass == zeros(length(df.biomass))
        @test df.litter_male == zeros(length(df.biomass))
    end
end


@testset "FemaleBiomass" begin
    mtg = Palm().mtg
    MultiScaleTreeGraph.Node(get_node(mtg, 7), NodeMTG("+", "Female", 1, 4))
    m = Dict(
        "Female" => (
            FemaleBiomass(),
            Status(carbon_allocation=15.0, state="undetermined", biomass=10.0, carbon_demand_stalk=2.0, carbon_demand_non_oil=1.0, carbon_demand_oil=3.0)
        )
    )
    vars = Dict{String,Any}("Female" => (:biomass, :biomass_stalk, :biomass_fruits))
    out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
    df = PlantSimEngine.convert_outputs_2(out, DataFrame)["Female"]
    @test df.biomass[1] ≈ 7.552083333333333
    @test df.biomass_stalk[1] ≈ 3.4722222222222223
    @test df.biomass_fruits[1] ≈ 4.079861111111111
    @test df.biomass == df.biomass_stalk + df.biomass_fruits
end


