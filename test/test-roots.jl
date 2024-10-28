@testset "RootGrowthFTSW" begin
    ini_root_depth = 30.0
    roots = XPalm.RootGrowthFTSW(ini_root_depth=ini_root_depth)
    @test [getfield(roots, i) for i in fieldnames(typeof(roots))] == [30.0, 0.3, 0.2]
end

@testset "RootGrowthFTSW + FTSW" begin
    ini_root_depth = 300.0
    soil = XPalm.FTSW(ini_root_depth=ini_root_depth)
    init = XPalm.soil_init_default(soil)
    init.ET0 = 2.5
    init.aPPFD = 1.0

    @testset "ModelList" begin
        m = ModelList(
            soil_water=XPalm.FTSW(ini_root_depth=ini_root_depth),
            root_growth=XPalm.RootGrowthFTSW(ini_root_depth=ini_root_depth),
            status=(NamedTuple(init)..., soil_depth=2000.0, TEff=9.0)
        )
        run!(m, meteo[1, :], executor=SequentialEx())
        @test m[:ftsw][1] ≈ 0.5610089099455698
        @test m[:root_depth][1] == 302.7
    end

    @testset "Mapping" begin
        mtg = Palm().mtg
        m = Dict(
            "Soil" => (
                XPalm.RootGrowthFTSW(ini_root_depth=ini_root_depth),
                XPalm.FTSW(ini_root_depth=ini_root_depth),
                Status(; NamedTuple(init)..., soil_depth=2000.0, TEff=9.0)
            )
        )
        vars = Dict{String,Any}("Soil" => (:root_depth, :ftsw))
        out = run!(mtg, m, meteo, outputs=vars, executor=SequentialEx())
        df = outputs(out, DataFrame)
        @test df.root_depth[1] ≈ 302.7
        @test df.root_depth[end] ≈ 2200.0
        @test df.ftsw[1] ≈ 0.5610089099455698
    end
end