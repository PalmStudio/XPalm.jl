@testset "RUE" begin
    m = ModelList(carbon_assimilation=XPalm.ConstantRUEModel(4.8),
        status=(aPPFD=300.0,))
    run!(m, meteo[1, :], executor=SequentialEx())

    @test m[:carbon_assimilation][1] ≈ 315.09846827133475
end

@testset "Beer+RUE" begin
    m = ModelList(
        light_interception=XPalm.Beer(0.5),
        carbon_assimilation=XPalm.ConstantRUEModel(4.8),
        status=(lai=fill(2.0, nrow(meteo)),))

    run!(m, meteo)

    @test m[:carbon_assimilation][1] ≈ 23.244236049954306
    @test m[:carbon_assimilation][end] ≈ 22.967373313544766
end