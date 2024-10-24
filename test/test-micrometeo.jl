@testset "ET0_BP" begin
    m = ModelList(ET0_BP())
    run!(m, meteo[1, :])
    @test m[:ET0][1] ≈ 2.82260378306658
end

@testset "thermal_time" begin
    mtg = Palm().mtg
    m = Dict("Plant" => DailyDegreeDays())
    # m = ModelList(
    #     thermal_time=DailyDegreeDays(),
    #     status=(TEff=fill(-Inf, nrow(meteo)), TT_since_init=fill(0.0, nrow(meteo)))
    # )
    vars = Dict{String,Any}("Plant" => (:TEff, :TT_since_init))
    out = run!(mtg, m, meteo, outputs=vars, executor=SequentialEx())
    df = outputs(out, DataFrame)
    @test df.TEff[1] ≈ 9.493478260869564
    @test df.TEff[end] ≈ 7.631656804733727
    @test df.TT_since_init[10] ≈ 96.18582446712631
    @test df.TT_since_init[end] ≈ 8350.554765084204
end

@testset "thermal_time_ftsw" begin
    mtg = Palm().mtg
    m = Dict("Plant" => (DegreeDaysFTSW(threshold_ftsw_stress=0.3), Status(ftsw=0.2,)))
    vars = Dict{String,Any}("Plant" => (:TEff,))
    out = run!(mtg, m, meteo, outputs=vars, executor=SequentialEx())
    df = outputs(out, DataFrame)
    # m = ModelList(
    #     DegreeDaysFTSW(),
    #     status=(threshold_ftsw_stress=0.3, ftsw=fill(ftsw_cst, nrow(meteo)))
    # )
    # run!(m, meteo, executor=SequentialEx())
    @test df.TEff[1] ≈ 6.328985507246377
    @test df.TEff[end] ≈ 5.087771203155818
end
