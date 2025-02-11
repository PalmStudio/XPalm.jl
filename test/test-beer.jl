@testset "Beer" begin
    m = ModelList(
        light_interception=Beer(0.5),
        status=(LAI=fill(2.0, nrow(meteo)),)
    )

    out = run!(m, meteo)

    @test out[:aPPFD][1] ≈ 23.060729431595018
    @test out[:aPPFD][end] ≈ 21.238220417042122
end
