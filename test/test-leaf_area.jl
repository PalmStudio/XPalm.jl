@testset "FinalPotentialAreaModel" begin
    m = ModelList(
        leaf_final_potential_area=FinalPotentialAreaModel(8 * 365, 0.0015, 12.0),
        status=(initiation_age=1825,)
    )
    out = run!(m)
    @test out[:final_potential_area][1] ≈ 7.500562499999999
end

@testset "PotentialAreaModel" begin
    m = ModelList(
        leaf_potential_area=PotentialAreaModel(560.0, 100.0),
        status=(TT_since_init=[1:1:10000;], final_potential_area=fill(8.0, 10000),)
    )
    out = run!(m)
    @test out[:potential_area][3000] ≈ 2.9890383871139807e-6
    @test out[:potential_area][5520] ≈ 7.999756547544795
    @test out[:maturity][1] ≈ false
    @test out[:maturity][9000] ≈ true
end

@testset "LeafAreaModel" begin
    m = ModelList(
        leaf_area=LeafAreaModel(80.0, 0.35, 0.0),
        status=(biomass=2000.0,)
    )
    out = run!(m)
    @test out[:leaf_area][1] ≈ 8.75
end

@testset "LAIModel" begin
    m = ModelList(
        LAIModel(30.0),
        status=(leaf_areas=[12.0],)
    )

    out = run!(m, executor=SequentialEx())
    @test out[:lai][1] == 0.4
end


@testset "LAIModel" begin
    mtg = Palm().mtg
    mapping = Dict(
        "Leaf" => (
            LeafBiomass(),
            LeafAreaModel(80.0, 0.35, 0.0),
            Status(carbon_allocation=10.0),
        ),
        "Scene" => (
            MultiScaleModel(LAIModel(30.0), [:leaf_areas => "Leaf" => :leaf_area]),
        )
    )
    vars = Dict{String,Any}("Scene" => (:lai, :leaf_area), "Leaf" => (:leaf_area,))
    out = run!(mtg, mapping, meteo, tracked_outputs=vars, executor=SequentialEx())
    df = convert_outputs(out, DataFrame)["Scene"]
    @test df.lai[1] ≈ 0.0010127314814814814
    @test df.lai[end] ≈ 4.2129629629632985
end