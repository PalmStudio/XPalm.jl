@testset "Beer" begin
    m = ModelList(
        light_interception=Beer(0.5),
        status=(lai=fill(2.0, nrow(meteo)),)
    )

    run!(m, meteo)

    @test m[:aPPFD][1] ≈ 23.060729431595018
    @test m[:aPPFD][end] ≈ 21.238220417042122
end
