@testset "FinalPotentialAreaModel" begin
    m = ModelList(
        leaf_final_potential_area=XPalm.FinalPotentialAreaModel(8 * 365, 0.0015, 12.0),
        status=(initiation_age=1825,)
    )
    run!(m)
    @test m[:final_potential_area][1] ≈ 7.500562499999999
end

@testset "PotentialAreaModel" begin
    m = ModelList(
        leaf_potential_area=XPalm.PotentialAreaModel(560.0, 100.0),
        status=(TT_since_init=[1:1:10000;], final_potential_area=fill(8.0, 10000),)
    )
    run!(m)
    @test m[:potential_area][3000] ≈ 2.9890383871139807e-6
    @test m[:potential_area][5520] ≈ 7.999756547544795
    @test m[:maturity][1] ≈ false
    @test m[:maturity][9000] ≈ true
end

@testset "LeafAreaModel" begin
    m = ModelList(
        leaf_area=XPalm.LeafAreaModel(80.0, 0.35, 0.0),
        status=(biomass=2000.0,)
    )
    run!(m)
    @test m[:leaf_area][1] ≈ 8.75
end

@testset "LAIModel" begin
    m = ModelList(
        XPalm.LAIModel(30.0),
        status=(leaf_area=12.0,)
    )

    run!(m, executor=SequentialEx())
    @test m[:lai][1] == 0.4
end


@testset "LAIModel" begin
    mtg = Palm().mtg
    mapping = Dict(
        "Leaf" => (
            XPalm.LeafBiomass(),
            XPalm.LeafAreaModel(80.0, 0.35, 0.0),
            Status(carbon_allocation=10.0),
        ),
        "Scene" => (
            MultiScaleModel(XPalm.LAIModel(30.0), [:leaf_area => "Leaf"]),
        )
    )
    vars = Dict{String,Any}("Scene" => (:lai, :leaf_area), "Leaf" => (:leaf_area,))
    out = run!(mtg, mapping, meteo, outputs=vars, executor=SequentialEx())
    df = filter(row -> row.organ == "Scene", outputs(out, DataFrame))
    @test df.lai[1] ≈ 0.0010127314814814814
    @test df.lai[end] ≈ 0.9276620370370258
end