@testset "read_parameters" begin
    @test vpalm_parameters["seed"] == 0
    @test vpalm_parameters["rachis_fresh_weight"] == uconvert.(u"kg", [
        2607.60521189879,
        2582.76405648725,
        2557.92290107571,
        2533.08174566417,
        2508.24059025263,
        2483.39943484109,
        2458.55827942956,
        2433.71712401802,
        2408.87596860648,
        2384.03481319494,
        2359.1936577834,
        2334.35250237186,
        2309.51134696033,
        2284.67019154879,
        2259.82903613725,
        2234.98788072571,
        2210.14672531417,
        2185.30556990263,
        2160.46441449109,
        2135.62325907956,
        2110.78210366802,
        2085.94094825648,
        2061.09979284494,
        2036.2586374334,
        2011.41748202186,
        1986.57632661033,
        1961.73517119879,
        1936.89401578725,
        1912.05286037571,
        1887.21170496417,
        1862.37054955263,
        1837.5293941411,
        1812.68823872956,
        1787.84708331802,
        1763.00592790648,
        1738.16477249494,
        1713.3236170834,
        1688.48246167187,
        1663.64130626033,
        1638.80015084879,
        1613.95899543725,
        1589.11784002571,
        1564.27668461417,
        1539.43552920264,
        1514.5943737911,
    ]u"g")
end

@testset "shared canonical VPalm parameter normalization" begin
    integer_keys = [
        "seed",
        "nb_leaves_emitted",
        "stem_growth_start",
        "nb_leaves_in_sheath",
        "internode_rank_no_expansion",
        "nbInflorescences",
    ]
    expected_integer_values = [12, 5, 3, 2, 4, 1]
    expected_key_order = [
        integer_keys...,
        "initial_stem_height",
        "leaf_max_angle",
        "rachis_fresh_weight",
        "rachis_final_lengths",
        "leaf_length_intercept",
        "leaf_length_slope",
        "elastic_modulus",
        "biomechanical_model",
    ]
    minimal_parameters = () ->
        XPalm.OrderedCollections.OrderedDict{String,Any}(
            "seed" => 12.0,
            "nb_leaves_emitted" => 5.0,
            "stem_growth_start" => 3.0,
            "nb_leaves_in_sheath" => 2.0,
            "internode_rank_no_expansion" => 4.0,
            "nbInflorescences" => 1.0,
        )

    normalizers = (
        XPalm._normalize_vpalm_parameters!,
        VPalm._normalize_vpalm_parameters!,
    )
    for normalize_parameters! in normalizers
        parameters = minimal_parameters()
        parameters["initial_stem_height"] = 125.0u"cm"
        parameters["leaf_max_angle"] = (pi / 2) * u"rad"
        parameters["rachis_fresh_weight"] = Any[1000.0, 250.0u"g"]
        parameters["rachis_final_lengths"] = Any[50.0u"cm", 2.0]
        parameters["leaf_length_intercept"] = 250.0u"cm"
        parameters["leaf_length_slope"] = 12.0u"cm/kg"
        parameters["elastic_modulus"] = 2.0u"GPa"
        biomechanical_model =
            XPalm.OrderedCollections.OrderedDict{String,Any}(
                "angle_max" => (pi / 2) * u"rad",
                "iterations" => 15,
            )
        parameters["biomechanical_model"] = biomechanical_model

        normalized = normalize_parameters!(parameters)

        @test normalized === parameters
        @test collect(keys(normalized)) == expected_key_order
        @test [normalized[key] for key in integer_keys] ==
              expected_integer_values
        @test all(normalized[key] isa Int for key in integer_keys)

        @test Unitful.unit(normalized["initial_stem_height"]) == u"m"
        @test ustrip(normalized["initial_stem_height"]) ≈ 1.25
        @test Unitful.unit(normalized["leaf_max_angle"]) == u"°"
        @test ustrip(normalized["leaf_max_angle"]) ≈ 90.0

        @test Unitful.unit.(normalized["rachis_fresh_weight"]) == fill(u"kg", 2)
        @test ustrip.(normalized["rachis_fresh_weight"]) ≈ [1.0, 0.25]
        @test Unitful.unit.(normalized["rachis_final_lengths"]) == fill(u"m", 2)
        @test ustrip.(normalized["rachis_final_lengths"]) ≈ [0.5, 2.0]

        @test Unitful.unit(normalized["leaf_length_intercept"]) == u"m"
        @test ustrip(normalized["leaf_length_intercept"]) ≈ 2.5
        @test Unitful.unit(normalized["leaf_length_slope"]) == u"m/kg"
        @test ustrip(normalized["leaf_length_slope"]) ≈ 0.12
        @test Unitful.unit(normalized["elastic_modulus"]) == u"MPa"
        @test ustrip(normalized["elastic_modulus"]) ≈ 2000.0

        @test normalized["biomechanical_model"] === biomechanical_model
        @test Unitful.unit(biomechanical_model["angle_max"]) == u"°"
        @test ustrip(biomechanical_model["angle_max"]) ≈ 90.0
    end

    for normalize_parameters! in normalizers
        warned = minimal_parameters()
        warned["initial_stem_height"] = 1.5
        @test_logs (
            :warn,
            "The `initial_stem_height` argument should have units, using m as default.",
        ) normalize_parameters!(warned; verbose=true)

        quiet = minimal_parameters()
        quiet["initial_stem_height"] = 1.5
        @test_logs normalize_parameters!(quiet; verbose=false)

        invalid_count = minimal_parameters()
        invalid_count["nb_leaves_emitted"] = 0
        count_exception = try
            normalize_parameters!(invalid_count)
            nothing
        catch error
            error
        end
        @test count_exception isa AssertionError
        if count_exception isa Exception
            @test sprint(showerror, count_exception) ==
                  "AssertionError: p[\"nb_leaves_emitted\"] > 0"
        end

        invalid_unit = minimal_parameters()
        invalid_unit["initial_stem_height"] = 1.0u"kg"
        exception = try
            normalize_parameters!(invalid_unit)
            nothing
        catch error
            error
        end
        @test exception isa ErrorException
        if exception isa Exception
            @test sprint(showerror, exception) ==
                  "Cannot convert initial_stem_height from kg to m"
        end
    end

    for normalize_parameters! in normalizers
        valid = minimal_parameters()
        valid["leaflet_length_juvenile_transition"] = 250.0u"cm"
        valid["leaflet_length_juvenile_exponent"] = 0.6
        valid["rachis_length_juvenile_transition_leaf"] = 12.0
        valid["rachis_length_juvenile_exponent"] = 0.5
        valid["cpoint_width_juvenile_coefficient"] = 16.703u"mm"
        valid["cpoint_width_juvenile_exponent"] = 0.5381
        valid["cpoint_height_juvenile_coefficient"] = 10.648u"mm"
        valid["cpoint_height_juvenile_exponent"] = 0.5125
        valid["cpoint_dimensions_juvenile_max_rachis_length"] = 171.0u"cm"
        valid["cpoint_dimensions_adult_min_rachis_length"] = 245.0u"cm"
        valid["leaf_base_width_juvenile"] = 1.0u"cm"
        valid["leaf_base_height_juvenile"] = 1.0u"mm"
        valid["leaf_base_dimensions_juvenile_max_emitted_leaf"] = 60.0
        valid["leaf_base_dimensions_adult_min_emitted_leaf"] = 110.0
        normalize_parameters!(valid)
        @test valid["leaflet_length_juvenile_transition"] == 2.5u"m"
        @test valid["rachis_length_juvenile_transition_leaf"] === 12
        @test valid["cpoint_width_juvenile_coefficient"] == 0.016703u"m"
        @test valid["cpoint_height_juvenile_coefficient"] == 0.010648u"m"
        @test valid["cpoint_dimensions_juvenile_max_rachis_length"] ==
              1.71u"m"
        @test valid["cpoint_dimensions_adult_min_rachis_length"] == 2.45u"m"
        @test valid["leaf_base_width_juvenile"] == 0.01u"m"
        @test valid["leaf_base_height_juvenile"] == 0.001u"m"
        @test valid["leaf_base_dimensions_juvenile_max_emitted_leaf"] === 60
        @test valid["leaf_base_dimensions_adult_min_emitted_leaf"] === 110

        missing_leaflet_exponent = minimal_parameters()
        missing_leaflet_exponent["leaflet_length_juvenile_transition"] =
            2.5u"m"
        @test_throws ArgumentError normalize_parameters!(missing_leaflet_exponent)

        missing_rachis_exponent = minimal_parameters()
        missing_rachis_exponent["rachis_length_juvenile_transition_leaf"] = 12
        @test_throws ArgumentError normalize_parameters!(missing_rachis_exponent)

        invalid_leaflet_transition = minimal_parameters()
        invalid_leaflet_transition["leaflet_length_juvenile_transition"] =
            0.0u"m"
        invalid_leaflet_transition["leaflet_length_juvenile_exponent"] = 0.6
        @test_throws ArgumentError normalize_parameters!(invalid_leaflet_transition)

        invalid_rachis_exponent = minimal_parameters()
        invalid_rachis_exponent["rachis_length_juvenile_transition_leaf"] = 12
        invalid_rachis_exponent["rachis_length_juvenile_exponent"] = 0.0
        @test_throws ArgumentError normalize_parameters!(invalid_rachis_exponent)

        incomplete_cpoint = minimal_parameters()
        incomplete_cpoint["cpoint_width_juvenile_coefficient"] = 0.016703u"m"
        @test_throws ArgumentError normalize_parameters!(incomplete_cpoint)

        invalid_cpoint = minimal_parameters()
        invalid_cpoint["cpoint_width_juvenile_coefficient"] = 0.016703u"m"
        invalid_cpoint["cpoint_width_juvenile_exponent"] = 0.5381
        invalid_cpoint["cpoint_height_juvenile_coefficient"] = 0.010648u"m"
        invalid_cpoint["cpoint_height_juvenile_exponent"] = 0.5125
        invalid_cpoint["cpoint_dimensions_juvenile_max_rachis_length"] =
            2.45u"m"
        invalid_cpoint["cpoint_dimensions_adult_min_rachis_length"] =
            1.71u"m"
        @test_throws ArgumentError normalize_parameters!(invalid_cpoint)

        dimensioned_cpoint_exponent = deepcopy(valid)
        dimensioned_cpoint_exponent["cpoint_width_juvenile_exponent"] =
            0.5381u"m"
        @test_throws ArgumentError normalize_parameters!(
            dimensioned_cpoint_exponent,
        )

        incomplete_leaf_base = minimal_parameters()
        incomplete_leaf_base["leaf_base_width_juvenile"] = 0.01u"m"
        @test_throws ArgumentError normalize_parameters!(incomplete_leaf_base)

        invalid_leaf_base = minimal_parameters()
        invalid_leaf_base["leaf_base_width_juvenile"] = 0.01u"m"
        invalid_leaf_base["leaf_base_height_juvenile"] = 0.001u"m"
        invalid_leaf_base["leaf_base_dimensions_juvenile_max_emitted_leaf"] =
            110
        invalid_leaf_base["leaf_base_dimensions_adult_min_emitted_leaf"] = 60
        @test_throws ArgumentError normalize_parameters!(invalid_leaf_base)
    end
end

@testset "XPalm and VPalm parameter readers share canonical values" begin
    static_path = joinpath(dirtest, "references", "vpalm-parameter_file.yml")
    dynamic_path = joinpath(
        dirtest,
        "references",
        "vpalm-parameter_file_dynamic.yml",
    )

    @test XPalm._vpalm_read_parameters(static_path) == VPalm.read_parameters(static_path)
    @test XPalm._vpalm_read_parameters(dynamic_path) == VPalm.read_parameters(dynamic_path)
    @test XPalm._default_vpalm_parameters(; type="static") ==
          VPalm.default_parameters(; type="static")
    @test XPalm._default_vpalm_parameters(; type="dynamic") ==
          VPalm.default_parameters(; type="dynamic")
    @test VPalm.default_parameters(type="dynamic")["xpalm_coupling"]["reserve_to_dry_mass"] ==
          1.0
end

@testset "read_parameters with missing rachis_final_lengths" begin
    @test vpalm_parameters2["leaf_length_intercept"] == 3.6801281u"m"
    @test vpalm_parameters2["leaf_length_slope"] == 0.08769u"m/kg"
end

@testset "write_parameters" begin
    vpalm_parameters_w = mktemp() do f, io
        VPalm.write_parameters(f, vpalm_parameters)
        return VPalm.read_parameters(f)
    end

    for (key, value) in vpalm_parameters
        if value != vpalm_parameters_w[key]
            println(
                "params[$key] = $(vpalm_parameters[key]) != params2[$key] = $(vpalm_parameters_w[key])",
            )
        end
        @test vpalm_parameters[key] == vpalm_parameters_w[key]
    end

end
