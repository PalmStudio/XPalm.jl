@testset "event-driven geometry properties" begin
    parameters = VPalm.default_parameters(type="dynamic")
    status = (
        radius_internodes=0.1,
        height_internodes=0.2,
        rank_leaves=-7,
    )

    internode_1 = Node(NodeMTG(:/, :Internode, 1, 4))
    internode_2 = Node(NodeMTG(:/, :Internode, 1, 4))
    rng_1 = Random.MersenneTwister(17)
    rng_2 = Random.MersenneTwister(17)

    @test VPalm._update_internode_properties!(
        internode_1,
        status,
        parameters,
        rng_1,
    )
    rng_after_initialization = copy(rng_1)
    initial_angle = internode_1.XEuler

    @test !VPalm._update_internode_properties!(
        internode_1,
        status,
        parameters,
        rng_1,
    )
    @test internode_1.XEuler == initial_angle
    @test rand(rng_1) == rand(rng_after_initialization)

    @test VPalm._update_internode_properties!(
        internode_2,
        status,
        parameters,
        rng_2,
    )
    @test internode_2.XEuler == initial_angle

    changed_status = merge(status, (height_internodes=0.25,))
    rng_before_dimension_update = copy(rng_1)
    @test !VPalm._update_internode_properties!(
        internode_1,
        changed_status,
        parameters,
        rng_1,
    )
    @test internode_1.length == 0.25u"m"
    @test internode_1.XEuler == initial_angle
    @test rand(rng_1) == rand(rng_before_dimension_update)

    leaf = Node(NodeMTG(:+, :Leaf, 1, 4))
    leaf_rng = Random.MersenneTwister(29)
    @test VPalm._update_leaf_properties_if_needed!(
        leaf,
        -7,
        3.0u"m",
        parameters,
        leaf_rng,
    ) == (true, true)
    initial_leaf_properties = (
        rank=leaf.rank,
        rachis_length=leaf.rachis_length,
        insertion_angle=leaf.zenithal_insertion_angle,
        cpoint_angle=leaf.zenithal_cpoint_angle,
    )
    rng_after_leaf_initialization = copy(leaf_rng)

    @test VPalm._update_leaf_properties_if_needed!(
        leaf,
        -7,
        3.0u"m",
        parameters,
        leaf_rng,
    ) == (false, false)
    @test (
        rank=leaf.rank,
        rachis_length=leaf.rachis_length,
        insertion_angle=leaf.zenithal_insertion_angle,
        cpoint_angle=leaf.zenithal_cpoint_angle,
    ) == initial_leaf_properties
    @test rand(leaf_rng) == rand(rng_after_leaf_initialization)

    @test VPalm._update_leaf_properties_if_needed!(
        leaf,
        -6,
        3.0u"m",
        parameters,
        leaf_rng,
    ) == (true, true)
    @test VPalm._update_leaf_properties_if_needed!(
        leaf,
        -6,
        3.2u"m",
        parameters,
        leaf_rng,
    ) == (false, true)
end

@testset "repeated pruning is structurally idempotent" begin
    palm = Palm(
        initiation_age=0,
        parameters=XPalm.default_parameters(),
        architecture=true,
    )
    scene = XPalm.xpalm_scene(
        palm;
        architecture=true,
        environment=first(meteo, 1),
    )
    run!(scene; steps=1, outputs=:none)

    internode_object = only(model_objects(scene; scale=:Internode))
    leaf_object = only(model_objects(scene; scale=:Leaf))
    internode = PlantSimEngine.source_node(scene, internode_object)
    leaf = only(node for node in children(internode) if symbol(node) == :Leaf)
    @test !isempty(children(leaf))

    unchanged_state = (
        rank=internode_object.status.rank_leaves,
        xeuler=internode.XEuler,
        rachis_length=leaf.rachis_length,
        insertion_angle=leaf.zenithal_insertion_angle,
        cpoint_angle=leaf.zenithal_cpoint_angle,
        descendant_ids=sort(node_id.(descendants(leaf))),
    )
    run!(scene; steps=1, outputs=:none)
    @test (
        rank=internode_object.status.rank_leaves,
        xeuler=internode.XEuler,
        rachis_length=leaf.rachis_length,
        insertion_angle=leaf.zenithal_insertion_angle,
        cpoint_angle=leaf.zenithal_cpoint_angle,
        descendant_ids=sort(node_id.(descendants(leaf))),
    ) == unchanged_state

    leaf_object.status.is_pruned = true
    run!(scene; steps=1, outputs=:none)
    @test !leaf.is_alive
    @test isempty(children(leaf))
    @test internode_object.status.geometry_removed

    state_after_first_pruning = (
        mtg_nodes=length(palm.mtg),
        graph_node_count=internode_object.status.graph_node_count,
        reconstructed=internode_object.status.is_reconstructed,
        geometry_removed=internode_object.status.geometry_removed,
    )

    leaf_object.status.is_pruned = true
    run!(scene; steps=1, outputs=:none)
    @test !leaf.is_alive
    @test isempty(children(leaf))
    @test (
        mtg_nodes=length(palm.mtg),
        graph_node_count=internode_object.status.graph_node_count,
        reconstructed=internode_object.status.is_reconstructed,
        geometry_removed=internode_object.status.geometry_removed,
    ) == state_after_first_pruning
end

function _vpalm_leaflet_unfolding_state(leaf)
    return Tuple(
        (
            id=node_id(leaflet),
            stiffness=leaflet.stiffness,
            zenithal_angle=leaflet.zenithal_angle,
            azimuthal_angle=leaflet.azimuthal_angle,
            segment_boundaries=copy(leaflet.leaflet_segment_boundaries),
            segment_lengths=copy(leaflet.leaflet_segment_lengths),
            segment_widths=copy(leaflet.leaflet_segment_widths),
            segment_angles_deg=copy(leaflet.leaflet_segment_angles_deg),
        )
        for leaflet in sort(descendants(leaf; symbol=:Leaflet); by=node_id)
    )
end

function _vpalm_leaflet_profile_references(leaf)
    return Tuple(
        (
            boundaries=leaflet.leaflet_segment_boundaries,
            lengths=leaflet.leaflet_segment_lengths,
            widths=leaflet.leaflet_segment_widths,
            angles_deg=leaflet.leaflet_segment_angles_deg,
        )
        for leaflet in sort(descendants(leaf; symbol=:Leaflet); by=node_id)
    )
end

function _vpalm_update_petiole_and_rachis!(leaf, biomass_leaf, parameters, rng)
    petiole = leaf[1]
    VPalm.update_petiole!(
        petiole,
        leaf.rachis_length,
        leaf.zenithal_insertion_angle,
        leaf.zenithal_cpoint_angle,
        parameters,
    )
    rachis = petiole[2]
    VPalm.update_rachis_angles!(
        rachis,
        leaf.rank,
        leaf.rachis_length,
        petiole.height_cpoint,
        petiole.width_cpoint,
        leaf.zenithal_cpoint_angle,
        biomass_leaf,
        parameters;
        rng=rng,
    )
    return nothing
end

@testset "leaflet unfolding stops after the rank-2 update" begin
    parameters = VPalm.default_parameters(type="dynamic")
    visible_rank = VPalm.first_visible_leaf_rank(parameters)
    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    leaf = Node(2, plant, NodeMTG(:+, :Leaf, 1, 4), Dict{Symbol,Any}())
    unique_id = Ref(3)
    rng = Random.MersenneTwister(20260830)
    biomass_leaf = 2.0u"kg"

    VPalm.leaf(
        unique_id,
        1,
        visible_rank,
        biomass_leaf,
        3.0u"m",
        leaf,
        parameters;
        rng=rng,
    )
    leaflets = sort(descendants(leaf; symbol=:Leaflet); by=node_id)
    @test length(leaflets) > 100

    folded_state = _vpalm_leaflet_unfolding_state(leaf)
    folded_profile_references = _vpalm_leaflet_profile_references(leaf)
    skipped_rank_leaf = deepcopy(leaf)
    skipped_rank_reference = deepcopy(leaf)
    skipped_rank_rng = copy(rng)
    skipped_rank_reference_rng = copy(rng)
    delete!(
        MultiScaleTreeGraph.node_attributes(skipped_rank_leaf),
        :leaflets_fully_unfolded,
    )
    @test !hasproperty(skipped_rank_leaf, :leaflets_fully_unfolded)

    leaf.rank = 2
    VPalm.update_leaf!(leaf, biomass_leaf, parameters; rng=rng)
    rank_2_state = _vpalm_leaflet_unfolding_state(leaf)
    rank_2_profile_references = _vpalm_leaflet_profile_references(leaf)

    @test rank_2_state != folded_state
    @test leaf.leaflets_fully_unfolded
    @test all(
        rank_2_profile_references[i].boundaries !== folded_profile_references[i].boundaries &&
        rank_2_profile_references[i].lengths !== folded_profile_references[i].lengths &&
        rank_2_profile_references[i].widths !== folded_profile_references[i].widths &&
        rank_2_profile_references[i].angles_deg !== folded_profile_references[i].angles_deg
        for i in eachindex(rank_2_profile_references)
    )
    @test all(
        leaflet.stiffness == leaflet.stiffness_0 &&
        leaflet.zenithal_angle == leaflet.v_angle &&
        leaflet.azimuthal_angle == leaflet.h_angle
        for leaflet in leaflets
    )
    @test all(
        begin
            profile = VPalm.leaflet_segment_profile(
                leaflet,
                leaflet.length,
                leaflet.width,
                leaflet.stiffness,
                0.5,
                leaflet.relative_position;
                xm_intercept=parameters["leaflet_xm_intercept"],
                xm_slope=parameters["leaflet_xm_slope"],
                ym_intercept=parameters["leaflet_ym_intercept"],
                ym_slope=parameters["leaflet_ym_slope"],
            )
            leaflet.leaflet_segment_boundaries == profile.boundaries &&
            leaflet.leaflet_segment_lengths == profile.lengths &&
            leaflet.leaflet_segment_widths == profile.widths &&
            leaflet.leaflet_segment_angles_deg == profile.angles_deg
        end
        for leaflet in leaflets
    )

    # A coarse or restarted simulation may skip the rank-2 transition. Older
    # MTGs also lack the explicit leaf-level maturity flag. Both cases must get
    # the same final leaflet state before entering the mature fast path.
    skipped_rank_leaf.rank = 3
    skipped_rank_leaf.rachis_length = 3.3u"m"
    skipped_rank_reference.rank = 2
    skipped_rank_reference.rachis_length = skipped_rank_leaf.rachis_length
    VPalm.update_leaf!(
        skipped_rank_leaf,
        biomass_leaf,
        parameters;
        rng=skipped_rank_rng,
    )
    VPalm.update_leaf!(
        skipped_rank_reference,
        biomass_leaf,
        parameters;
        rng=skipped_rank_reference_rng,
    )
    @test skipped_rank_leaf.leaflets_fully_unfolded
    @test skipped_rank_reference.leaflets_fully_unfolded
    @test _vpalm_leaflet_unfolding_state(skipped_rank_leaf) ==
          _vpalm_leaflet_unfolding_state(skipped_rank_reference)

    # From rank 3 onward, only the petiole and rachis continue to change. Use a
    # rachis-only reference to prove that the skipped leaflet phase adds no RNG
    # draws while retaining the existing biomechanical RNG contract.
    reference_leaf = deepcopy(leaf)
    reference_rng = copy(rng)
    petiole = leaf[1]
    rachis_segments = sort(descendants(leaf; symbol=:RachisSegment); by=node_id)
    petiole_width_before = petiole.width_cpoint
    rachis_lengths_before = Tuple(segment.length for segment in rachis_segments)

    leaf.rank = 3
    leaf.rachis_length = 3.3u"m"
    reference_leaf.rank = leaf.rank
    reference_leaf.rachis_length = leaf.rachis_length
    VPalm.update_leaf!(leaf, biomass_leaf, parameters; rng=rng)
    _vpalm_update_petiole_and_rachis!(reference_leaf, biomass_leaf, parameters, reference_rng)

    @test _vpalm_leaflet_unfolding_state(leaf) == rank_2_state
    rank_3_profile_references = _vpalm_leaflet_profile_references(leaf)
    @test all(
        rank_3_profile_references[i].boundaries === rank_2_profile_references[i].boundaries &&
        rank_3_profile_references[i].lengths === rank_2_profile_references[i].lengths &&
        rank_3_profile_references[i].widths === rank_2_profile_references[i].widths &&
        rank_3_profile_references[i].angles_deg === rank_2_profile_references[i].angles_deg
        for i in eachindex(rank_3_profile_references)
    )
    @test petiole.width_cpoint != petiole_width_before
    @test Tuple(segment.length for segment in rachis_segments) != rachis_lengths_before
    @test rand(rng) == rand(reference_rng)

    rank_3_state = _vpalm_leaflet_unfolding_state(leaf)
    reference_leaf = deepcopy(leaf)
    reference_rng = copy(rng)
    leaf.rank = 4
    leaf.rachis_length = 3.6u"m"
    reference_leaf.rank = leaf.rank
    reference_leaf.rachis_length = leaf.rachis_length
    VPalm.update_leaf!(leaf, biomass_leaf, parameters; rng=rng)
    _vpalm_update_petiole_and_rachis!(reference_leaf, biomass_leaf, parameters, reference_rng)

    @test _vpalm_leaflet_unfolding_state(leaf) == rank_3_state == rank_2_state
    rank_4_profile_references = _vpalm_leaflet_profile_references(leaf)
    @test all(
        rank_4_profile_references[i].boundaries === rank_3_profile_references[i].boundaries &&
        rank_4_profile_references[i].lengths === rank_3_profile_references[i].lengths &&
        rank_4_profile_references[i].widths === rank_3_profile_references[i].widths &&
        rank_4_profile_references[i].angles_deg === rank_3_profile_references[i].angles_deg
        for i in eachindex(rank_4_profile_references)
    )
    @test rand(rng) == rand(reference_rng)
end

function _vpalm_rachis_transition_state(leaf)
    return Tuple(
        (
            id=node_id(segment),
            parent_id=node_id(parent(segment)),
            index=index(segment),
            width=segment.width,
            height=segment.height,
            length=segment.length,
            zenithal_angle=segment.zenithal_angle_global,
            azimuthal_angle=segment.azimuthal_angle_global,
            torsion_angle=segment.torsion_angle_global,
            x=segment.x,
            y=segment.y,
            z=segment.z,
        )
        for segment in sort(descendants(leaf; symbol=:RachisSegment); by=node_id)
    )
end

function _vpalm_mature_update_allocations!(leaf, biomass, parameters, rng, workspace)
    leaf.rank = 3
    leaf.rachis_length = 3.3u"m"
    VPalm.update_leaf!(leaf, biomass, parameters; rng=rng, workspace=workspace)

    leaf.rank = 4
    leaf.rachis_length = 3.6u"m"
    return @allocated VPalm.update_leaf!(
        leaf,
        biomass,
        parameters;
        rng=rng,
        workspace=workspace,
    )
end

@testset "rachis biomechanics workspace is exact and reusable" begin
    parameters = VPalm.default_parameters(type="dynamic")
    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    leaf = Node(2, plant, NodeMTG(:+, :Leaf, 1, 4), Dict{Symbol,Any}())
    unique_id = Ref(3)
    rng = StableRNG(20260830)
    biomass_leaf = 2.0u"kg"

    VPalm.leaf(
        unique_id,
        1,
        2,
        biomass_leaf,
        3.0u"m",
        leaf,
        parameters;
        rng=rng,
    )
    @test leaf.leaflets_fully_unfolded

    reference_leaf = deepcopy(leaf)
    reference_rng = copy(rng)
    workspace = VPalm.RachisBiomechanicsWorkspace(parameters)
    iteration_workspace = workspace.bend_iteration
    buffer_references = Tuple(
        getfield(iteration_workspace, field)
        for field in fieldnames(typeof(iteration_workspace))
    )
    leaflet_profile_references = _vpalm_leaflet_profile_references(leaf)

    for (rank, rachis_length) in ((3, 3.3u"m"), (4, 3.6u"m"))
        leaf.rank = rank
        leaf.rachis_length = rachis_length
        reference_leaf.rank = rank
        reference_leaf.rachis_length = rachis_length

        VPalm.update_leaf!(
            leaf,
            biomass_leaf,
            parameters;
            rng=rng,
            workspace=workspace,
        )
        VPalm.update_leaf!(
            reference_leaf,
            biomass_leaf,
            parameters;
            rng=reference_rng,
        )

        @test _vpalm_rachis_transition_state(leaf) ==
              _vpalm_rachis_transition_state(reference_leaf)
        current_buffers = Tuple(
            getfield(iteration_workspace, field)
            for field in fieldnames(typeof(iteration_workspace))
        )
        @test all(
            current_buffers[i] === buffer_references[i]
            for i in eachindex(buffer_references)
        )
        @test all(
            begin
                current = _vpalm_leaflet_profile_references(leaf)[i]
                initial = leaflet_profile_references[i]
                current.boundaries === initial.boundaries &&
                current.lengths === initial.lengths &&
                current.widths === initial.widths &&
                current.angles_deg === initial.angles_deg
            end
            for i in eachindex(leaflet_profile_references)
        )
    end
    @test rand(rng) == rand(reference_rng)

    cached_leaf = deepcopy(reference_leaf)
    legacy_leaf = deepcopy(reference_leaf)
    cached_rng = StableRNG(44)
    legacy_rng = StableRNG(44)
    cached_workspace = VPalm.RachisBiomechanicsWorkspace(parameters)
    cached_allocations = _vpalm_mature_update_allocations!(
        cached_leaf,
        biomass_leaf,
        parameters,
        cached_rng,
        cached_workspace,
    )
    legacy_allocations = _vpalm_mature_update_allocations!(
        legacy_leaf,
        biomass_leaf,
        parameters,
        legacy_rng,
        nothing,
    )

    @test _vpalm_rachis_transition_state(cached_leaf) ==
          _vpalm_rachis_transition_state(legacy_leaf)
    @test rand(cached_rng) == rand(legacy_rng)
    @test cached_allocations < legacy_allocations
end
