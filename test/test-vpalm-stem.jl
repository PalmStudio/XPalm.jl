@testset "stem bending" begin
    @test VPalm.stem_bending(vpalm_parameters["stem_bending_mean"], vpalm_parameters["stem_bending_sd"], rng=StableRNG(1)) == 0.0
    @test VPalm.stem_bending(45.0, vpalm_parameters["stem_bending_sd"], rng=StableRNG(1)) == 45.0
    @test VPalm.stem_bending(45.0, 1.0, rng=StableRNG(1)) ≈ 44.467479925135876
end

@testset "stem height" begin
    # Before stem_growth_start:
    @test VPalm.stem_height(100, vpalm_parameters["initial_stem_height"], vpalm_parameters["stem_height_coefficient"], vpalm_parameters["internode_length_at_maturity"], 120.0, 0.0u"m", rng=StableRNG(1)) == 0.3005242665305668u"m"

    # After stem_growth_start:
    @test VPalm.stem_height(vpalm_parameters["nb_leaves_emitted"], vpalm_parameters["initial_stem_height"], vpalm_parameters["stem_height_coefficient"], vpalm_parameters["internode_length_at_maturity"], vpalm_parameters["stem_growth_start"], 0.0u"m", rng=StableRNG(1)) == 1.1801911326167471u"m"
end

@testset "stem diameter" begin
    @test VPalm.stem_diameter(5.0335230597u"m",
        vpalm_parameters["stem_diameter_max"],
        vpalm_parameters["stem_diameter_slope"],
        vpalm_parameters["stem_diameter_inflection"],
        0.0u"m", # To avoid randomness
        vpalm_parameters["stem_diameter_snag"],
        rng=StableRNG(1)
    ) == 0.16228677550579518u"m"
end