distance3(p0, p1) = sqrt(sum((p1 .- p0) .^ 2))

@testset "XPalm dry biomass to VPalm growth contract" begin
    parameters = VPalm.default_parameters(type="dynamic")
    coupling = parameters["xpalm_coupling"]

    @test VPalm.fresh_biomass_from_dry_mass(
        308.0,
        coupling["rachis_dry_matter_fraction"],
    ) == 1.0u"kg"
    @test VPalm.fresh_biomass_from_dry_mass(-1.0, 0.5) == 0.0u"kg"
    @test_throws ArgumentError VPalm.fresh_biomass_from_dry_mass(1.0, 0.0)

    model = VPalm.LeafFreshBiomass(
        leaflets_dry_matter_fraction=0.50,
        rachis_dry_matter_fraction=0.25,
        petiole_dry_matter_fraction=0.50,
        reserve_to_dry_mass=1.0,
    )
    scene = test_scene(
        :Leaf,
        model;
        status=Status(
            biomass_leaflets=300.0,
            biomass_rachis=300.0,
            biomass_petiole=400.0,
            reserve=100.0,
        ),
    )
    run!(scene)
    status = test_status(scene, :Leaf)
    @test status.fresh_biomass_leaflets ≈ 0.66
    @test status.fresh_biomass_rachis ≈ 1.32
    @test status.fresh_biomass_petiole ≈ 0.88
    @test 1000.0 * (
        0.50 * status.fresh_biomass_leaflets +
        0.25 * status.fresh_biomass_rachis +
        0.50 * status.fresh_biomass_petiole
    ) ≈ 1100.0

    # Outputs are current states, not accumulated flows.
    status.reserve = 0.0
    run!(scene)
    @test status.fresh_biomass_leaflets ≈ 0.60
    @test status.fresh_biomass_rachis ≈ 1.20
    @test status.fresh_biomass_petiole ≈ 0.80
    @test status.fresh_biomass_rachis * u"kg" ≈
          VPalm.fresh_biomass_from_dry_mass(300.0, 0.25)

    empty_scene = test_scene(
        :Leaf,
        model;
        status=Status(
            biomass_leaflets=0.0,
            biomass_rachis=0.0,
            biomass_petiole=0.0,
            reserve=100.0,
        ),
    )
    run!(empty_scene)
    empty_status = test_status(empty_scene, :Leaf)
    @test empty_status.fresh_biomass_leaflets == 0.0
    @test empty_status.fresh_biomass_rachis == 0.0
    @test empty_status.fresh_biomass_petiole == 0.0

    @test_throws ArgumentError VPalm.LeafFreshBiomass(
        leaflets_dry_matter_fraction=0.0,
        rachis_dry_matter_fraction=0.25,
        petiole_dry_matter_fraction=0.50,
    )
    @test_throws ArgumentError VPalm.LeafFreshBiomass(
        leaflets_dry_matter_fraction=0.50,
        rachis_dry_matter_fraction=0.25,
        petiole_dry_matter_fraction=0.50,
        reserve_to_dry_mass=-1.0,
    )
    integer_parameter_model = VPalm.LeafFreshBiomass(1, 1, 1, 1)
    @test integer_parameter_model isa VPalm.LeafFreshBiomass{Float64}
    @test PlantSimEngine.outputs_(integer_parameter_model).fresh_biomass_rachis ===
          0.0

    @test VPalm.coupled_leaf_dimension_scale(
        40.0,
        1.0,
        80.0,
        0.30,
        0.30,
        coupling["dimension_growth_exponent"],
    ) ≈ sqrt(0.5)
    @test VPalm.coupled_leaf_dimension_scale(
        160.0,
        1.0,
        80.0,
        0.30,
        0.30,
        coupling["dimension_growth_exponent"],
    ) == 1.0
end

@testset "dynamic rachis age allometry" begin
    parameters = VPalm.default_parameters(type="dynamic")

    @test parameters["rachis_length_age_intercept"] == 0.834u"m"
    @test parameters["rachis_length_age_slope"] == 0.03222u"m"
    @test parameters["rachis_length_juvenile_transition_leaf"] == 12
    @test parameters["rachis_length_juvenile_exponent"] == 0.575
    @test VPalm.final_rachis_length(1, 0.0u"kg", parameters) ≈
          0.29245u"m" atol = 0.0001u"m"
    @test VPalm.final_rachis_length(11, 0.0u"kg", parameters) ≈
          1.16107u"m" atol = 0.0001u"m"
    @test VPalm.final_rachis_length(12, 0.0u"kg", parameters) ≈
          1.22064u"m"
    @test VPalm.final_rachis_length(50, 0.0u"kg", parameters) ≈ 2.445u"m"
    @test VPalm.final_rachis_length(120, 0.0u"kg", parameters) ≈ 4.7004u"m"
    @test VPalm.final_rachis_length(250, 0.0u"kg", parameters) == 6.62u"m"
    @test VPalm.rachis_fresh_biomass_for_geometry(
        4.0u"m",
        1.0u"kg",
        parameters,
    ) ≈ (4.0 / 1.31)u"kg"

    @test VPalm.first_visible_leaf_rank(parameters) == -7
    @test VPalm.is_visible_leaf_rank(-7, parameters)
    @test !VPalm.is_visible_leaf_rank(-8, parameters)
end

@testset "provisional juvenile petiole-base dimensions" begin
    parameters = VPalm.default_parameters(type="dynamic")
    juvenile = VPalm.leaf_base_dimensions(1, parameters)
    at_juvenile_limit = VPalm.leaf_base_dimensions(60, parameters)
    transition_middle = VPalm.leaf_base_dimensions(85, parameters)
    adult = VPalm.leaf_base_dimensions(110, parameters)

    @test juvenile == (width_base=0.01u"m", height_base=0.001u"m")
    @test at_juvenile_limit == juvenile
    @test transition_middle.width_base ≈ sqrt(0.01 * 0.3) * u"m"
    @test transition_middle.height_base ≈ sqrt(0.001 * 0.1) * u"m"
    @test adult == (width_base=0.3u"m", height_base=0.1u"m")

    emitted_leaf_numbers = 1:120
    dimensions =
        VPalm.leaf_base_dimensions.(emitted_leaf_numbers, Ref(parameters))
    @test issorted(getproperty.(dimensions, :width_base))
    @test issorted(getproperty.(dimensions, :height_base))

    static_parameters = VPalm.default_parameters(type="static")
    @test VPalm.leaf_base_dimensions(1, static_parameters) ==
          (
              width_base=static_parameters["leaf_base_width"],
              height_base=static_parameters["leaf_base_height"],
          )
    @test_throws ArgumentError VPalm.leaf_base_dimensions(-1, parameters)

    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    unique_id = Ref(2)
    petiole = VPalm.petiole(
        unique_id,
        plant,
        1,
        5,
        0.60u"m",
        10.0u"°",
        20.0u"°",
        parameters;
        rng=Random.MersenneTwister(1),
    )
    segments = descendants(petiole, symbol=:PetioleSegment)
    expected_cpoint = VPalm.petiole_dimensions_at_cpoint(0.60u"m", parameters)
    @test petiole.width_base == juvenile.width_base
    @test petiole.height_base == juvenile.height_base
    @test petiole.width_cpoint == expected_cpoint.width_cpoint
    @test petiole.height_cpoint == expected_cpoint.height_cpoint
    @test first(segments).width == juvenile.width_base
    @test first(segments).height == juvenile.height_base
    @test last(segments).width ≈ expected_cpoint.width_cpoint
    @test last(segments).height ≈ expected_cpoint.height_cpoint

    # Exercise the real update path through the juvenile-to-adult bridge. The
    # leaf-base dimensions stay attached to the immutable emission index while
    # the C-point dimensions follow the elongating rachis.
    for rachis_length in (2.0u"m", 3.0u"m")
        VPalm.update_petiole!(
            petiole,
            rachis_length,
            10.0u"°",
            20.0u"°",
            parameters,
        )
        expected_cpoint =
            VPalm.petiole_dimensions_at_cpoint(rachis_length, parameters)
        @test petiole.width_base == juvenile.width_base
        @test petiole.height_base == juvenile.height_base
        @test petiole.width_cpoint ≈ expected_cpoint.width_cpoint
        @test petiole.height_cpoint ≈ expected_cpoint.height_cpoint
        @test last(segments).width ≈ expected_cpoint.width_cpoint
        @test last(segments).height ≈ expected_cpoint.height_cpoint
    end

    legacy_dynamic = deepcopy(parameters)
    for key in (
        VPalm._LEAF_BASE_JUVENILE_DIMENSION_KEYS...,
        VPalm._CPOINT_JUVENILE_DIMENSION_KEYS...,
    )
        delete!(legacy_dynamic, key)
    end
    legacy_petiole = VPalm.petiole(
        Ref(1000),
        plant,
        1,
        5,
        0.60u"m",
        10.0u"°",
        20.0u"°",
        legacy_dynamic;
        rng=Random.MersenneTwister(1),
    )
    historical_cpoint = VPalm.petiole_dimensions_at_cpoint(
        0.60u"m",
        legacy_dynamic["cpoint_width_intercept"],
        legacy_dynamic["cpoint_width_slope"],
        legacy_dynamic["cpoint_height_width_ratio"],
    )
    @test legacy_petiole.width_base == legacy_dynamic["leaf_base_width"]
    @test legacy_petiole.height_base == legacy_dynamic["leaf_base_height"]
    @test legacy_petiole.width_cpoint == historical_cpoint.width_cpoint
    @test legacy_petiole.height_cpoint == historical_cpoint.height_cpoint
end

@testset "JPCE juvenile rachis section allometry" begin
    parameters = VPalm.default_parameters(type="dynamic")
    juvenile_max =
        parameters["cpoint_dimensions_juvenile_max_rachis_length"]
    adult_min = parameters["cpoint_dimensions_adult_min_rachis_length"]

    @test juvenile_max == 1.71u"m"
    @test adult_min == 2.45u"m"
    @test parameters["rachis_width_tip"] == 0.003u"m"

    width_cpoint = 8.0u"mm"
    height_cpoint = 5.0u"mm"
    ratio_point_c = 0.5220
    ratio_point_a = 1.0053
    position_ratio_max = 0.6636
    ratio_max = 1.5789
    @test VPalm._biomechanical_rachis_width(
        0.0,
        height_cpoint,
        parameters["height_rachis_tappering"],
        width_cpoint,
        ratio_point_c,
        ratio_point_a,
        position_ratio_max,
        ratio_max,
    ) ≈ width_cpoint
    historical_position = 0.5
    @test VPalm._biomechanical_rachis_width(
        historical_position,
        height_cpoint,
        parameters["height_rachis_tappering"],
        nothing,
        ratio_point_c,
        ratio_point_a,
        position_ratio_max,
        ratio_max,
    ) ≈ VPalm.rachis_height(
        historical_position,
        height_cpoint,
        parameters["height_rachis_tappering"],
    ) / VPalm.height_to_width_ratio(
        historical_position,
        ratio_point_c,
        ratio_point_a,
        position_ratio_max,
        ratio_max,
    )
    @test VPalm._biomechanical_cpoint_width(
        0.60u"m",
        height_cpoint,
        width_cpoint,
        parameters,
    ) == width_cpoint
    @test isnothing(
        VPalm._biomechanical_cpoint_width(
            adult_min,
            height_cpoint,
            width_cpoint,
            parameters,
        ),
    )

    juvenile_dimensions =
        VPalm.petiole_dimensions_at_cpoint(0.60u"m", parameters)
    @test juvenile_dimensions.width_cpoint ≈
          parameters["cpoint_width_juvenile_coefficient"] *
          0.60^parameters["cpoint_width_juvenile_exponent"]
    @test juvenile_dimensions.height_cpoint ≈
          parameters["cpoint_height_juvenile_coefficient"] *
          0.60^parameters["cpoint_height_juvenile_exponent"]

    adult_dimensions(rachis_length) = VPalm.petiole_dimensions_at_cpoint(
        rachis_length,
        parameters["cpoint_width_intercept"],
        parameters["cpoint_width_slope"],
        parameters["cpoint_height_width_ratio"],
    )
    transition_end =
        VPalm.petiole_dimensions_at_cpoint(adult_min, parameters)
    expected_transition_end = adult_dimensions(adult_min)
    @test transition_end.width_cpoint ≈
          expected_transition_end.width_cpoint
    @test transition_end.height_cpoint ≈
          expected_transition_end.height_cpoint
    @test VPalm.petiole_dimensions_at_cpoint(3.0u"m", parameters) ==
          adult_dimensions(3.0u"m")

    # The smoothstep bridge is continuous in both value and slope at the two
    # evidence boundaries.
    step = 1.0e-5u"m"
    for (boundary, field) in Iterators.product(
        (juvenile_max, adult_min),
        (:width_cpoint, :height_cpoint),
    )
        at_boundary = getproperty(
            VPalm.petiole_dimensions_at_cpoint(boundary, parameters),
            field,
        )
        left_slope = (
            at_boundary -
            getproperty(
                VPalm.petiole_dimensions_at_cpoint(boundary - step, parameters),
                field,
            )
        ) / step
        right_slope = (
            getproperty(
                VPalm.petiole_dimensions_at_cpoint(boundary + step, parameters),
                field,
            ) - at_boundary
        ) / step
        @test left_slope ≈ right_slope rtol = 5.0e-4
    end

    # Direct EKA1 fixtures from `data palm chamber.xlsx`, Feuil1, H/M/N,
    # rows 7:20. The section is assumed to be C from the measurement context;
    # its exact position was not explicitly recorded in the workbook.
    rachis_lengths = [
        0.600,
        0.610,
        0.685,
        0.865,
        0.925,
        0.960,
        0.990,
        1.110,
        1.180,
        1.235,
        1.280,
        1.580,
        1.315,
        1.710,
    ]u"m"
    observed_widths =
        [12.4, 12.0, 13.0, 15.0, 16.0, 16.5, 19.5, 18.5, 19.0, 19.5, 21.3, 21.5, 18.0, 18.7]u"mm"
    observed_heights =
        [7.0, 8.5, 8.0, 10.0, 10.5, 11.0, 11.0, 12.5, 15.0, 12.8, 12.0, 13.0, 11.5, 11.0]u"mm"
    predicted =
        VPalm.petiole_dimensions_at_cpoint.(rachis_lengths, Ref(parameters))
    predicted_widths = getproperty.(predicted, :width_cpoint)
    predicted_heights = getproperty.(predicted, :height_cpoint)
    width_rmse = sqrt(
        sum(ustrip.(u"mm", predicted_widths .- observed_widths) .^ 2) /
        length(rachis_lengths),
    )
    height_rmse = sqrt(
        sum(ustrip.(u"mm", predicted_heights .- observed_heights) .^ 2) /
        length(rachis_lengths),
    )
    @test width_rmse ≈ 1.4941207771900948
    @test height_rmse ≈ 1.3798232197491125
    historical_predictions = adult_dimensions.(rachis_lengths)
    historical_width_rmse = sqrt(
        sum(
            ustrip.(
                u"mm",
                getproperty.(historical_predictions, :width_cpoint) .-
                observed_widths,
            ) .^ 2,
        ) / length(rachis_lengths),
    )
    historical_height_rmse = sqrt(
        sum(
            ustrip.(
                u"mm",
                getproperty.(historical_predictions, :height_cpoint) .-
                observed_heights,
            ) .^ 2,
        ) / length(rachis_lengths),
    )
    @test width_rmse < historical_width_rmse
    @test height_rmse < historical_height_rmse

    static_parameters = VPalm.default_parameters(type="static")
    @test !haskey(
        static_parameters,
        "cpoint_width_juvenile_coefficient",
    )
    @test VPalm.petiole_dimensions_at_cpoint(0.60u"m", static_parameters) ==
          VPalm.petiole_dimensions_at_cpoint(
              0.60u"m",
              static_parameters["cpoint_width_intercept"],
              static_parameters["cpoint_width_slope"],
              static_parameters["cpoint_height_width_ratio"],
          )
    @test isnothing(
        VPalm._biomechanical_cpoint_width(
            0.60u"m",
            height_cpoint,
            width_cpoint,
            static_parameters,
        ),
    )
end

@testset "JPCE juvenile leaflet length allometry" begin
    parameters = VPalm.default_parameters(type="dynamic")
    transition = parameters["leaflet_length_juvenile_transition"]
    exponent = parameters["leaflet_length_juvenile_exponent"]
    adult_length(rachis_length) =
        parameters["leaflet_length_at_b_intercept"] +
        parameters["leaflet_length_at_b_slope"] * rachis_length
    maximum_length(rachis_length) = VPalm.leaflet_length_max(
        VPalm.leaflet_length_at_bpoint(rachis_length, parameters),
        parameters["relative_position_bpoint"],
        parameters["relative_length_first_leaflet"],
        parameters["relative_length_last_leaflet"],
        parameters["relative_position_leaflet_max_length"],
    )
    maximum_width(rachis_length) = VPalm.leaflet_width_max(
        VPalm.leaflet_width_at_bpoint(
            rachis_length,
            parameters["leaflet_width_at_b_intercept"],
            parameters["leaflet_width_at_b_slope"],
        ),
        parameters["relative_position_bpoint"],
        parameters["relative_width_first_leaflet"],
        parameters["relative_width_last_leaflet"],
        parameters["relative_position_leaflet_max_width"],
    )

    @test transition == 3.72u"m"
    @test exponent == 0.646
    @test VPalm.leaflet_length_at_bpoint(transition, parameters) ≈
          adult_length(transition)
    @test VPalm.leaflet_length_at_bpoint(4.0u"m", parameters) ≈
          adult_length(4.0u"m")
    # Representative JPCE EKA1/EKA2 fixtures spanning the juvenile fit and
    # one adult point. The width allometry is deliberately left unchanged.
    @test maximum_length(0.60u"m") ≈ 0.260207960u"m" rtol = 1.0e-8
    @test maximum_length(0.85u"m") ≈ 0.325866335u"m" rtol = 1.0e-8
    @test maximum_length(1.39u"m") ≈ 0.447736429u"m" rtol = 1.0e-8
    @test maximum_length(1.85u"m") ≈ 0.538552204u"m" rtol = 1.0e-8
    @test maximum_length(2.77u"m") ≈ 0.698999398u"m" rtol = 1.0e-8
    @test maximum_length(4.05u"m") ≈ 0.864360615u"m" rtol = 1.0e-8
    @test maximum_width(0.60u"m") ≈
          0.031038385824742117u"m" rtol = 1.0e-12

    static_parameters = VPalm.default_parameters(type="static")
    @test !haskey(static_parameters, "leaflet_length_juvenile_transition")
    @test VPalm.leaflet_length_at_bpoint(1.0u"m", static_parameters) ==
          VPalm.leaflet_length_at_bpoint(
              1.0u"m",
              static_parameters["leaflet_length_at_b_intercept"],
              static_parameters["leaflet_length_at_b_slope"],
          )
end

@testset "dynamic leaf elongation preserves leaflet topology" begin
    parameters = VPalm.default_parameters(type="dynamic")
    parameters["nbLeaflets_SDP"] = 0.0
    parameters["relative_position_bpoint_sd"] = 0.0
    current_length = 2.8u"m"
    final_length = 4.0u"m"
    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    leaf = Node(2, plant, NodeMTG(:+, :Leaf, 1, 4), Dict{Symbol,Any}())
    leaf.rank = -7
    leaf.rachis_length = current_length
    leaf.zenithal_insertion_angle = 0.0u"°"
    leaf.zenithal_cpoint_angle = 0.0u"°"

    unique_id = Ref(3)
    VPalm.build_leaf(
        unique_id,
        1,
        leaf,
        2.0u"kg",
        parameters;
        rachis_final_length=final_length,
        rng=Random.MersenneTwister(1),
    )

    petiole = only(descendants(leaf, symbol=:Petiole))
    leaflets = descendants(leaf, symbol=:Leaflet)
    original_petiole_ids = node_id.(descendants(petiole, symbol=:PetioleSegment))
    original_rachis_ids = node_id.(descendants(leaf, symbol=:RachisSegment))
    original_leaflet_ids = node_id.(leaflets)
    original_leaflets = Dict(
        node_id(node) => (
            parent=node_id(parent(node)),
            offset=node.offset,
            relative_position=node.relative_position,
            length=node.length,
            width=node.width,
            segment_lengths=copy(node.leaflet_segment_lengths),
            segment_widths=copy(node.leaflet_segment_widths),
        )
        for node in leaflets
    )

    expected_leaflets_per_side = VPalm.compute_number_of_leaflets(
        final_length,
        parameters["leaflets_nb_max"],
        parameters["leaflets_nb_min"],
        parameters["leaflets_nb_slope"],
        parameters["leaflets_nb_inflexion"],
        parameters["nbLeaflets_SDP"];
        rng=Random.MersenneTwister(2),
    )
    leaflet_length_at_b =
        VPalm.leaflet_length_at_bpoint(final_length, parameters)
    leaflet_max_length = VPalm.leaflet_length_max(
        leaflet_length_at_b,
        parameters["relative_position_bpoint"],
        parameters["relative_length_first_leaflet"],
        parameters["relative_length_last_leaflet"],
        parameters["relative_position_leaflet_max_length"],
        parameters["relative_position_bpoint_sd"],
        Random.MersenneTwister(2),
    )
    leaflet_width_at_b = VPalm.leaflet_width_at_bpoint(
        final_length,
        parameters["leaflet_width_at_b_intercept"],
        parameters["leaflet_width_at_b_slope"],
    )
    leaflet_max_width = VPalm.leaflet_width_max(
        leaflet_width_at_b,
        parameters["relative_position_bpoint"],
        parameters["relative_width_first_leaflet"],
        parameters["relative_width_last_leaflet"],
        parameters["relative_position_leaflet_max_width"],
        parameters["relative_position_bpoint_sd"],
        Random.MersenneTwister(2),
    )
    insertion_position(node, rachis_length) =
        (MultiScaleTreeGraph.index(parent(node)) - 1) *
        rachis_length / parameters["rachis_nb_segments"] + node.offset

    @test length(leaflets) == 2 * expected_leaflets_per_side
    @test all(
        node.length ≈ leaflet_max_length * VPalm.relative_leaflet_length(
            node.relative_position,
            parameters["relative_length_first_leaflet"],
            parameters["relative_length_last_leaflet"],
            parameters["relative_position_leaflet_max_length"],
        ) &&
        node.width ≈ leaflet_max_width * VPalm.relative_leaflet_width(
            node.relative_position,
            parameters["relative_width_first_leaflet"],
            parameters["relative_width_last_leaflet"],
            parameters["relative_position_leaflet_max_width"],
        ) &&
        insertion_position(node, current_length) ≈
        node.relative_position * current_length
        for node in leaflets
    )

    leaf.rank = 2
    leaf.rachis_length = final_length
    leaf.zenithal_insertion_angle = 20.0u"°"
    leaf.zenithal_cpoint_angle = 30.0u"°"
    VPalm.update_leaf!(
        leaf,
        4.0u"kg",
        parameters;
        rng=Random.MersenneTwister(1),
    )

    updated_leaflets = descendants(leaf, symbol=:Leaflet)
    updated_rachis_segments =
        sort(descendants(leaf, symbol=:RachisSegment); by=MultiScaleTreeGraph.index)
    terminal_rachis_segment = last(updated_rachis_segments)
    penultimate_rachis_segment = parent(terminal_rachis_segment)
    expected_cpoint = VPalm.petiole_dimensions_at_cpoint(
        leaf.rachis_length,
        parameters["cpoint_width_intercept"],
        parameters["cpoint_width_slope"],
        parameters["cpoint_height_width_ratio"],
    )

    @test node_id.(descendants(petiole, symbol=:PetioleSegment)) == original_petiole_ids
    @test node_id.(descendants(leaf, symbol=:RachisSegment)) == original_rachis_ids
    @test node_id.(updated_leaflets) == original_leaflet_ids
    @test symbol(penultimate_rachis_segment) == :RachisSegment
    @test (
        terminal_rachis_segment.zenithal_angle_global,
        terminal_rachis_segment.azimuthal_angle_global,
        terminal_rachis_segment.torsion_angle_global,
    ) == (
        penultimate_rachis_segment.zenithal_angle_global,
        penultimate_rachis_segment.azimuthal_angle_global,
        penultimate_rachis_segment.torsion_angle_global,
    )
    @test petiole.width_cpoint ≈ expected_cpoint.width_cpoint
    @test petiole.height_cpoint ≈ expected_cpoint.height_cpoint
    @test all(begin
        original = original_leaflets[node_id(node)]
        node_id(parent(node)) == original.parent &&
        node.relative_position == original.relative_position &&
        node.length == original.length &&
        node.width == original.width &&
        node.leaflet_segment_lengths == original.segment_lengths &&
        node.leaflet_segment_widths == original.segment_widths &&
        node.offset ≈ original.offset * final_length / current_length &&
        insertion_position(node, final_length) ≈
        node.relative_position * final_length
    end for node in updated_leaflets)
    @test any(
        node.offset != original_leaflets[node_id(node)].offset
        for node in updated_leaflets
    )
end

@testset "coupled leaflet dimensions grow once and freeze at opening" begin
    parameters = VPalm.default_parameters(type="dynamic")
    parameters["nbLeaflets_SDP"] = 0.0
    parameters["relative_position_bpoint_sd"] = 0.0
    reference_length = 4.0u"m"
    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    leaf = Node(2, plant, NodeMTG(:+, :Leaf, 1, 4), Dict{Symbol,Any}())
    leaf.rank = -7
    leaf.rachis_length = 2.0u"m"
    leaf.zenithal_insertion_angle = 0.0u"°"
    leaf.zenithal_cpoint_angle = 0.0u"°"

    unique_id = Ref(3)
    VPalm.build_leaf(
        unique_id,
        1,
        leaf,
        2.0u"kg",
        parameters;
        rachis_final_length=reference_length,
        leaflet_fresh_biomass=1.5u"kg",
        leaflet_dimension_scale=0.5,
        rng=Random.MersenneTwister(11),
    )
    leaflets = sort(descendants(leaf; symbol=:Leaflet); by=node_id)
    identities = Tuple(node_id.(leaflets))
    parents = Tuple(node_id(parent(node)) for node in leaflets)
    references = Tuple(
        (length=node.reference_length, width=node.reference_width)
        for node in leaflets
    )
    @test !leaf.leaflet_dimensions_frozen
    @test leaf.leaflet_dimension_scale == 0.5
    @test all(
        leaflets[i].length == references[i].length * 0.5 &&
        leaflets[i].width == references[i].width * 0.5
        for i in eachindex(leaflets)
    )

    leaf.rank = 0
    VPalm.update_leaf!(
        leaf,
        2.5u"kg",
        parameters;
        leaflet_fresh_biomass=2.0u"kg",
        leaflet_dimension_scale=0.8,
        rng=Random.MersenneTwister(12),
    )
    @test !leaf.leaflet_dimensions_frozen
    @test all(
        leaflets[i].length == references[i].length * 0.8 &&
        leaflets[i].width == references[i].width * 0.8
        for i in eachindex(leaflets)
    )

    leaf.rank = 1
    VPalm.update_leaf!(
        leaf,
        3.0u"kg",
        parameters;
        leaflet_fresh_biomass=2.5u"kg",
        leaflet_dimension_scale=0.9,
        rng=Random.MersenneTwister(13),
    )
    opened_dimensions = Tuple((node.length, node.width) for node in leaflets)
    @test leaf.leaflet_dimensions_frozen
    @test leaf.leaflet_dimension_scale == 0.9

    leaf.rank = 2
    VPalm.update_leaf!(
        leaf,
        4.0u"kg",
        parameters;
        leaflet_fresh_biomass=3.0u"kg",
        leaflet_dimension_scale=1.0,
        rng=Random.MersenneTwister(14),
    )
    @test Tuple((node.length, node.width) for node in leaflets) ==
          opened_dimensions
    @test Tuple(node_id.(leaflets)) == identities
    @test Tuple(node_id(parent(node)) for node in leaflets) == parents
end

@testset "standalone leaflet allometry remains current-length by default" begin
    parameters = VPalm.default_parameters(type="dynamic")
    parameters["nbLeaflets_SDP"] = 0.0
    parameters["relative_position_bpoint_sd"] = 0.0
    final_length = 4.0u"m"
    current_length = VPalm.rachis_expansion(-7, final_length)

    default_plant = Node(NodeMTG(:/, :Plant, 1, 1))
    default_leaf = Node(
        2,
        default_plant,
        NodeMTG(:+, :Leaf, 1, 4),
        Dict{Symbol,Any}(),
    )
    VPalm.leaf(
        Ref(3),
        1,
        -7,
        2.0u"kg",
        final_length,
        default_leaf,
        parameters;
        rng=Random.MersenneTwister(1),
    )

    coupled_plant = Node(NodeMTG(:/, :Plant, 1, 1))
    coupled_leaf = Node(
        2,
        coupled_plant,
        NodeMTG(:+, :Leaf, 1, 4),
        Dict{Symbol,Any}(),
    )
    VPalm.leaf(
        Ref(3),
        1,
        -7,
        2.0u"kg",
        final_length,
        coupled_leaf,
        parameters;
        leaflet_allometry_rachis_length=final_length,
        rng=Random.MersenneTwister(1),
    )

    expected_current_leaflets = VPalm.compute_number_of_leaflets(
        current_length,
        parameters["leaflets_nb_max"],
        parameters["leaflets_nb_min"],
        parameters["leaflets_nb_slope"],
        parameters["leaflets_nb_inflexion"],
        parameters["nbLeaflets_SDP"];
        rng=Random.MersenneTwister(2),
    )
    expected_final_leaflets = VPalm.compute_number_of_leaflets(
        final_length,
        parameters["leaflets_nb_max"],
        parameters["leaflets_nb_min"],
        parameters["leaflets_nb_slope"],
        parameters["leaflets_nb_inflexion"],
        parameters["nbLeaflets_SDP"];
        rng=Random.MersenneTwister(2),
    )

    @test length(descendants(default_leaf; symbol=:Leaflet)) ==
          2 * expected_current_leaflets
    @test length(descendants(coupled_leaf; symbol=:Leaflet)) ==
          2 * expected_final_leaflets
    @test expected_current_leaflets != expected_final_leaflets
end

@testset "snag" begin
    x_scale = 10.
    y_scale = 20.
    z_scale = 30.
    hexagon_half_span = sqrt(3.0) / 4.0
    snag_ref = VPalm.SNAG
    @test snag_ref == VPalm.snag(1.0, 1.0, 1.0)
    scaled_snag = VPalm.snag(x_scale, y_scale, z_scale)

    # Test snag min/max coordinates
    ref_y_extent = let points = GeometryBasics.coordinates(snag_ref)
        x_coords_ref = getindex.(points, 1)
        y_coords_ref = getindex.(points, 2)
        z_coords_ref = getindex.(points, 3)
        @test minimum(x_coords_ref) ≈ 0.0 # x min
        @test maximum(x_coords_ref) ≈ 1.0 # x max
        @test minimum(y_coords_ref) ≈ -hexagon_half_span # y min
        @test maximum(y_coords_ref) ≈ hexagon_half_span  # y max
        @test minimum(z_coords_ref) ≈ -0.5  # z min
        @test maximum(z_coords_ref) ≈ 0.5  # z max
        maximum(abs.(y_coords_ref))
    end
    ref_z_extent = let points = GeometryBasics.coordinates(snag_ref)
        z_coords_ref = getindex.(points, 3)
        maximum(abs.(z_coords_ref))
    end

    let points = GeometryBasics.coordinates(scaled_snag)
        x_coords_scaled = getindex.(points, 1)
        y_coords_scaled = getindex.(points, 2)
        z_coords_scaled = getindex.(points, 3)
        @test minimum(x_coords_scaled) ≈ 0.0 # x min
        @test maximum(x_coords_scaled) ≈ x_scale # x max
        @test maximum(abs.(y_coords_scaled)) > ref_y_extent
        @test maximum(abs.(z_coords_scaled)) > ref_z_extent
    end
end

@testset "cylinder" begin
    x_scale = 10.
    z_scale = 30.
    cylinder_ref = VPalm.cylinder()
    @test cylinder_ref == VPalm.cylinder(1.0, 1.0)
    @test cylinder_ref.origin ≈ GeometryBasics.Point3(0.0, 0.0, 0.0)
    @test cylinder_ref.extremity ≈ GeometryBasics.Point3(0.0, 0.0, 1.0)
    @test cylinder_ref.r ≈ 1.0

    cylinder_scaled = VPalm.cylinder(x_scale, z_scale)
    @test cylinder_scaled.origin ≈ GeometryBasics.Point3(0.0, 0.0, 0.0)
    @test cylinder_scaled.extremity ≈ GeometryBasics.Point3(0.0, 0.0, z_scale)
    @test cylinder_scaled.r ≈ x_scale
end

@testset "add_geometry" begin
    mtg = VPalm.mtg_skeleton(vpalm_parameters)
    refmesh_cylinder = PlantGeom.RefMesh("cylinder", GeometryBasics.mesh(VPalm.cylinder()))
    VPalm.add_geometry!(mtg, refmesh_cylinder)

    internode_id = findfirst(i -> symbol(get_node(mtg, i)) == :Internode, 1:length(mtg))
    @test internode_id !== nothing
    internode = get_node(mtg, internode_id)
    VPalm.add_geometry!(internode, refmesh_cylinder)

    t = internode.geometry.transformation
    p0 = t(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0))
    p1 = t(GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.0))
    @test p0 ≈ GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0)
    @test distance3(p0, p1) ≈ ustrip(internode.length)
    @test distance3(p0, t(GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0))) ≈ ustrip(internode.width) / 2
    @test distance3(p0, t(GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0))) ≈ ustrip(internode.width) / 2

    petiole_id = findfirst(i -> symbol(get_node(mtg, i)) == :Petiole, 1:length(mtg))
    @test petiole_id !== nothing
    petiole_segment_id = findfirst(i -> symbol(get_node(mtg, i)) == :PetioleSegment, 1:length(mtg))
    @test petiole_segment_id !== nothing
    petiole_segment = get_node(mtg, petiole_segment_id)
    t_petiole = petiole_segment.geometry.transformation
    p_petiole = t_petiole(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0))
    @test distance3(p_petiole, t_petiole(GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0))) ≈ ustrip(petiole_segment.height) / 2
    @test distance3(p_petiole, t_petiole(GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0))) ≈ ustrip(petiole_segment.width) / 2
    @test distance3(p_petiole, t_petiole(GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.0))) ≈ ustrip(petiole_segment.length)

    rachis_id = findfirst(i -> symbol(get_node(mtg, i)) == :Rachis, 1:length(mtg))
    @test rachis_id !== nothing
    rachis_segment_id = findfirst(i -> symbol(get_node(mtg, i)) == :RachisSegment, 1:length(mtg))
    @test rachis_segment_id !== nothing
    rachis_segment = get_node(mtg, rachis_segment_id)
    t_rachis = rachis_segment.geometry.transformation
    p_rachis = t_rachis(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0))
    @test distance3(p_rachis, t_rachis(GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0))) ≈ ustrip(rachis_segment.height) / 2
    @test distance3(p_rachis, t_rachis(GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0))) ≈ ustrip(rachis_segment.width) / 2
    @test distance3(p_rachis, t_rachis(GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.0))) ≈ ustrip(rachis_segment.length)

    dead_leaf_id = findfirst(i -> symbol(get_node(mtg, i)) == :Leaf && !get_node(mtg, i).is_alive, 1:length(mtg))
    @test dead_leaf_id !== nothing
    @test get_node(mtg, dead_leaf_id).geometry isa PlantGeom.ExtrudedTubeGeometry

    # leaflet_id = findfirst(i -> symbol(get_node(mtg, i)) == :Leaflet, 1:length(mtg))
    # @test leaflet_id !== nothing
    # leaflet = get_node(mtg, leaflet_id)
    # @test leaflet.relative_position == 0.0
    # @test leaflet.leaflet_rank == 0.0
end

@testset "dynamic geometry uses registered status inputs" begin
    parameters = XPalm.default_parameters()
    parameters["vpalm"]["nbLeaflets_SDP"] = 0.0
    parameters["vpalm"]["relative_position_bpoint_sd"] = 0.0
    palm = Palm(
        initiation_age=0,
        parameters=parameters,
        architecture=true,
    )
    seed_leaf = only(descendants(palm.mtg; symbol=:Leaf))
    seed_leaflets = descendants(seed_leaf; symbol=:Leaflet)
    vpalm_parameters = parameters["vpalm"]
    seed_final_length = VPalm.final_rachis_length(1, 0.0u"kg", vpalm_parameters)
    seed_current_length = VPalm.rachis_expansion(1, seed_final_length)
    expected_final_leaflets = VPalm.compute_number_of_leaflets(
        seed_final_length,
        vpalm_parameters["leaflets_nb_max"],
        vpalm_parameters["leaflets_nb_min"],
        vpalm_parameters["leaflets_nb_slope"],
        vpalm_parameters["leaflets_nb_inflexion"],
        vpalm_parameters["nbLeaflets_SDP"];
        rng=Random.MersenneTwister(2),
    )
    expected_current_leaflets = VPalm.compute_number_of_leaflets(
        seed_current_length,
        vpalm_parameters["leaflets_nb_max"],
        vpalm_parameters["leaflets_nb_min"],
        vpalm_parameters["leaflets_nb_slope"],
        vpalm_parameters["leaflets_nb_inflexion"],
        vpalm_parameters["nbLeaflets_SDP"];
        rng=Random.MersenneTwister(2),
    )
    @test seed_leaf.rachis_length ≈ seed_current_length
    @test length(seed_leaflets) == 2 * expected_final_leaflets
    # Both lengths now legitimately reach the juvenile minimum leaflet count.
    # Verify the stronger contract directly: stored reference dimensions use
    # the final, not the currently expanded, rachis length.
    @test expected_final_leaflets == expected_current_leaflets
    reference_leaflet = first(seed_leaflets)
    final_max_length = VPalm.leaflet_length_max(
        VPalm.leaflet_length_at_bpoint(seed_final_length, vpalm_parameters),
        vpalm_parameters["relative_position_bpoint"],
        vpalm_parameters["relative_length_first_leaflet"],
        vpalm_parameters["relative_length_last_leaflet"],
        vpalm_parameters["relative_position_leaflet_max_length"],
    )
    current_max_length = VPalm.leaflet_length_max(
        VPalm.leaflet_length_at_bpoint(seed_current_length, vpalm_parameters),
        vpalm_parameters["relative_position_bpoint"],
        vpalm_parameters["relative_length_first_leaflet"],
        vpalm_parameters["relative_length_last_leaflet"],
        vpalm_parameters["relative_position_leaflet_max_length"],
    )
    relative_reference_length = VPalm.relative_leaflet_length(
        reference_leaflet.relative_position,
        vpalm_parameters["relative_length_first_leaflet"],
        vpalm_parameters["relative_length_last_leaflet"],
        vpalm_parameters["relative_position_leaflet_max_length"],
    )
    @test reference_leaflet.reference_length ≈
          final_max_length * relative_reference_length
    @test !isapprox(
        reference_leaflet.reference_length,
        current_max_length * relative_reference_length,
    )

    scene = XPalm.xpalm_scene(
        palm;
        architecture=true,
        environment=meteo[1:1, :],
    )

    compiled = PlantSimEngine.Advanced.refresh_bindings!(scene)
    bindings = PlantSimEngine.Diagnostics.explain_bindings(compiled)
    geometry_pruning_binding = only(
        row for row in bindings
        if row.application_id == :Internode__geometry && row.input == :is_pruned
    )
    @test geometry_pruning_binding.source_application_ids == [:Leaf__leaf_pruning]
    @test geometry_pruning_binding.carrier_hint != :temporal_stream
    for input in (:biomass_leaflets, :biomass_rachis, :biomass_petiole, :reserve)
        binding = only(
            row for row in bindings
            if row.application_id == :Leaf__fresh_biomass && row.input == input
        )
        @test binding.source_application_ids == [:Leaf__leaf_pruning]
        @test binding.carrier_hint != :temporal_stream
    end
    for input in (
        :fresh_biomass_leaflets,
        :fresh_biomass_rachis,
        :fresh_biomass_petiole,
    )
        binding = only(
            row for row in bindings
            if row.application_id == :Internode__geometry && row.input == input
        )
        @test binding.source_application_ids == [:Leaf__fresh_biomass]
        @test binding.carrier_hint != :temporal_stream
    end
    geometry_rachis_dry_mass_binding = only(
        row for row in bindings
        if row.application_id == :Internode__geometry &&
           row.input == :biomass_rachis
    )
    @test geometry_rachis_dry_mass_binding.source_application_ids ==
          [:Leaf__leaf_pruning]
    schedule = Dict(
        row.application_id => row.execution_index
        for row in PlantSimEngine.Diagnostics.explain_schedule(compiled)
    )
    @test schedule[:Leaf__leaf_pruning] <
          schedule[:Leaf__fresh_biomass] <
          schedule[:Internode__geometry]

    run!(scene; steps=1, outputs=:none)

    internode_object = only(model_objects(scene; scale=:Internode))
    internode = PlantSimEngine.source_node(scene, internode_object)
    leaf = internode[1]
    @test PlantSimEngine.model_status(scene, internode) ===
          internode_object.status
    @test internode_object.status.is_reconstructed
    @test isfinite(ustrip(internode.width))
    @test isfinite(ustrip(internode.length))
    @test isfinite(ustrip(leaf.rachis_length))
    leaf_object = only(model_objects(scene; scale=:Leaf))
    @test leaf.coupled_leaflet_fresh_biomass ≈
          leaf_object.status.fresh_biomass_leaflets * u"kg"
    @test leaf.coupled_rachis_fresh_biomass ≈
          leaf_object.status.fresh_biomass_rachis * u"kg"
    @test leaf.coupled_petiole_fresh_biomass ≈
          leaf_object.status.fresh_biomass_petiole * u"kg"
    @test !haskey(
        MultiScaleTreeGraph.node_attributes(internode),
        :plantsimengine_status,
    )

    pruned_scene = XPalm.xpalm_scene(
        Palm(
            initiation_age=0,
            parameters=XPalm.default_parameters(),
            architecture=true,
        );
        architecture=true,
        environment=meteo[1:1, :],
    )
    pruned_object = only(model_objects(pruned_scene; scale=:Internode))
    pruned_leaf_object = only(model_objects(pruned_scene; scale=:Leaf))
    pruned_internode = PlantSimEngine.source_node(pruned_scene, pruned_object)
    pruned_leaf = pruned_internode[1]
    geometry_scales = (:Petiole, :PetioleSegment, :Rachis, :RachisSegment, :Leaflet)
    registered_before = Dict(
        scale => length(model_objects(pruned_scene; scale=scale))
        for scale in geometry_scales
    )
    mtg_before = Dict(
        scale => length(descendants(pruned_leaf; symbol=scale))
        for scale in geometry_scales
    )

    run!(pruned_scene; steps=1, outputs=:none)
    @test !isempty(children(pruned_leaf))
    @test Dict(
        scale => length(model_objects(pruned_scene; scale=scale))
        for scale in geometry_scales
    ) == registered_before
    @test Dict(
        scale => length(descendants(pruned_leaf; symbol=scale))
        for scale in geometry_scales
    ) == mtg_before

    pruned_leaf_object.status.is_pruned = true
    run!(pruned_scene; steps=1, outputs=:none)

    @test pruned_leaf_object.status.is_pruned
    @test !pruned_leaf.is_alive
    @test isempty(children(pruned_leaf))
    @test all(isempty(model_objects(pruned_scene; scale=scale)) for scale in geometry_scales)
end


# @testset "leaflets" begin
#     vpalm_parameters_ = copy(vpalm_parameters)
#     vpalm_parameters_["leaflet_stiffness_sd"] = 0.0u"MPa"
#     plane_ref = PlantGeom.RefMesh("Plane", PlantGeom.to_geometrybasics(VPalm.plane()))
#     mtg = VPalm.mtg_skeleton(vpalm_parameters_; rng=nothing)
#     leaflet_id = findfirst(i -> symbol(get_node(mtg, i)) == :Leaflet, 1:length(mtg))
#     @test leaflet_id !== nothing
#     leaflet_node = get_node(mtg, leaflet_id)
#     rachis_node = parent(leaflet_node)
#     VPalm.add_leaflet_geometry!(leaflet_node,
#         leaflet_node.width,
#         1.5u"m",
#         GeometryBasics.Point{3,Float64}(0.0, 0.0, 1.5),
#         (; rachis_node.zenithal_angle_global, rachis_node.azimuthal_angle_global, rachis_node.torsion_angle_global),
#         0.0u"°",
#         0.0u"°",
#         plane_ref
#     )
#     @test isapprox(leaflet_node.zenithal_angle, 16.6575840747922u"°", atol=0.01u"°") #! this uses randomness, and we can't control it atm.
#     @test leaflet_node.lamina_angle ≈ 140.0u"°"
#     @test leaflet_node.tapering ≈ 0.5
# end
