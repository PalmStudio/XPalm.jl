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
