
aPPFD_radiation = 60.0
@testset "RUE" begin
    m = ModelList(carbon_assimilation=ConstantRUEModel(4.8), status=(aPPFD=aPPFD_radiation,))
    out = run!(m, meteo[1, :], executor=SequentialEx())

    @test out[:carbon_assimilation][1] ≈ aPPFD_radiation / Constants().J_to_umol * 4.8
end

@testset "Multiscale RUE" begin
    mtg = Palm().mtg
    m = Dict(
        "Plant" => (
            ConstantRUEModel(4.8),
            Status(aPPFD=aPPFD_radiation,) # aPPFD in mol[PAR] m[soil]⁻² d⁻¹
        )
    )
    vars = Dict{String,Any}("Plant" => (:carbon_assimilation,))
    out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
    df = convert_outputs(out, DataFrame)["Plant"]

    @test df.carbon_assimilation[1] ≈ aPPFD_radiation / Constants().J_to_umol * 4.8
    # @test df.carbon_assimilation[end] ≈ 22.967373313544766
end

@testset "Beer+RUE" begin
    leaf_area_plant = 1.0
    plant_area = 10000.0 / 136.0
    scene_leaf_area = leaf_area_plant * plant_area
    mtg = Palm().mtg
    m = Dict(
        "Scene" => (
            Beer(0.5),
            Status(lai=2.0,),
        ),
        "Plant" => (
            MultiScaleModel(SceneToPlantLightPartitioning(plant_area), [:aPPFD_scene => "Scene" => :aPPFD]),
            ConstantRUEModel(4.8),
            Status(leaf_area=leaf_area_plant, scene_leaf_area=scene_leaf_area,)
        )
    )
    vars = Dict{String,Any}("Plant" => (:carbon_assimilation,))
    out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
    df = convert_outputs(out, DataFrame)["Plant"]

    @test df.carbon_assimilation[1] ≈ 24.221335070384264
    @test df.carbon_assimilation[end] ≈ 22.30710240739654
end