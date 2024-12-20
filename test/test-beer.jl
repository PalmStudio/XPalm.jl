@testset "Beer" begin
    m = ModelList(
        light_interception=Beer(0.5),
        status=(lai=fill(2.0, nrow(meteo)),)
    )

    run!(m, meteo)

    @test m[:aPPFD][1] ≈ 22.130449739227334
    @test m[:aPPFD][end] ≈ 21.866853342270748
end
