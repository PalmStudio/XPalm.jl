@testset "ET0_BP" begin
    m = ModelList(ET0_BP())
    run!(m, meteo[1, :])

    @test m[:ET0][1] ≈ 2.82260378306658
end