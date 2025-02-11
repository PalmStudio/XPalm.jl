@testset "ET0_BP" begin
    m = ModelList(ET0_BP())
    out = run!(m, meteo[1, :])
    @test out[:ET0][1] ≈ 0.855813392356407
end

@testset "thermal_time" begin
    mtg = Palm().mtg
    m = Dict("Plant" => DailyDegreeDays())
    vars = Dict{String,Any}("Plant" => (:TEff, :TT_since_init))
    out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
    df = outputs(out, DataFrame)
    @test df.TEff[1] ≈ 8.996814638030823
    @test df.TEff[end] ≈ 9.608695832784498
    @test df.TT_since_init[10] ≈ 89.3153902056305
    @test df.TT_since_init[end] ≈ 39522.93549866889
end

@testset "thermal_time_ftsw" begin
    mtg = Palm().mtg
    m = Dict("Plant" => (DegreeDaysFTSW(threshold_ftsw_stress=0.3), Status(ftsw=0.2,)))
    vars = Dict{String,Any}("Plant" => (:TEff,))
    out = run!(mtg, m, meteo, tracked_outputs=vars, executor=SequentialEx())
    df = outputs(out, DataFrame)
    # m = ModelList(
    #     DegreeDaysFTSW(),
    #     status=(threshold_ftsw_stress=0.3, ftsw=fill(ftsw_cst, nrow(meteo)))
    # )
    # run!(m, meteo, executor=SequentialEx())
    @test df.TEff[1] ≈ 5.9978764253538825
    @test df.TEff[end] ≈ 6.405797221856333
end
