
@testset "Palm" begin
    p = Palm(nsteps=nrow(meteo))

    scene = p.mtg
    soil = scene[1]
    plant = scene[2]
    roots = plant[1]

    @test NamedTuple(scene[:models].status[1]) == (leaf_area=-Inf, lai=-Inf, aPPFD=-Inf, ET0=-Inf, TEff=-Inf)
    @test PlantSimEngine.outputs_(scene[:models].models.potential_evapotranspiration) == (ET0=-Inf,)

    XPalm.run_XPalm(p, meteo)

    # Checking the results:
    @test p.mtg[:models].status[1][:ET0] ≈ 2.82260378306658
    @test soil[:models].status[1][:ET0] == p.mtg[:models].status[1][:ET0]
    @test soil[:models].status[1][:ftsw] ≈ 0.865783368088583
    @test soil[:models].status[1][:ftsw] == roots[:models].status[1][:ftsw]
    @test roots[:models].status[1][:root_depth] ≈ 102.84804347826086

    leaf = get_node(p.mtg, 8)
    @test leaf[:models].status[1][:potential_area] ≈ 0.0015
    # The potential area stays constant over time:
    @test leaf[:models].status[end][:potential_area] == leaf[:models].status[1][:potential_area]

    leaf_101 = get_node(p.mtg, 101)
    @test leaf_101[:models].status[:potential_area][1] == -Inf
    @test leaf_101[:models].status[:potential_area][end] == 1.801275

    @test plant[:models].status.leaf_area[1] == 0.0015
    @test plant[:models].status.leaf_area[end] ≈ 104.24123270547945

    @test sum(scene[:models].status.aPPFD) ≈ 5670.096747485619
    @test sum(plant[:models].status.carbon_assimilation) ≈ 437901.666687009
end

