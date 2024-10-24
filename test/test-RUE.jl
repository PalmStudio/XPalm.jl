
aPPFD_radiation = 60.0
@testset "RUE" begin
    m = ModelList(carbon_assimilation=XPalm.ConstantRUEModel(4.8), status=(aPPFD=aPPFD_radiation,))
    run!(m, meteo[1, :], executor=SequentialEx())

    @test m[:carbon_assimilation][1] ≈ aPPFD_radiation / Constants().J_to_umol * 4.8
end

@testset "Multiscale RUE" begin
    mtg = Palm().mtg
    m = Dict(
        "Plant" => (
            XPalm.ConstantRUEModel(4.8),
            Status(aPPFD=aPPFD_radiation,) # aPPFD in mol[PAR] m[soil]⁻² d⁻¹
        )
    )
    vars = Dict{String,Any}("Plant" => (:carbon_assimilation,))
    out = run!(mtg, m, meteo, outputs=vars, executor=SequentialEx())
    df = outputs(out, DataFrame)

    @test df.carbon_assimilation[1] ≈ aPPFD_radiation / Constants().J_to_umol * 4.8
    # @test df.carbon_assimilation[end] ≈ 22.967373313544766
end

@testset "Beer+RUE" begin
    mtg = Palm().mtg
    m = Dict(
        "Scene" => (
            XPalm.Beer(0.5),
            Status(lai=2.0,),
        ),
        "Plant" => (
            MultiScaleModel(XPalm.SceneToPlantLightPartitioning(), [:aPPFD_scene => "Scene" => :aPPFD]),
            XPalm.ConstantRUEModel(4.8),
            Status(plant_leaf_area=1.0, scene_leaf_area=1.0,)
        )
    )
    vars = Dict{String,Any}("Plant" => (:carbon_assimilation,))
    out = run!(mtg, m, meteo, outputs=vars, executor=SequentialEx())
    df = outputs(out, DataFrame)

    @test df.carbon_assimilation[1] ≈ 23.244236049954306
    @test df.carbon_assimilation[end] ≈ 22.967373313544766
end