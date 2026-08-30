function _vpalm_leaf_geometry_fingerprint(leaf)
    nodes = sort(descendants(leaf); by=node_id)
    petiole = only(node for node in nodes if symbol(node) == :Petiole)
    rachis = only(node for node in nodes if symbol(node) == :Rachis)
    leaflets = filter(node -> symbol(node) == :Leaflet, nodes)

    parents = Tuple(
        (
            id=node_id(node),
            class=symbol(node),
            parent_id=node_id(parent(node)),
            parent_class=symbol(parent(node)),
        ) for node in nodes
    )
    leaflet_local = Tuple(
        (
            id=node_id(node),
            length=node.length,
            width=node.width,
            offset=node.offset,
            relative_position=node.relative_position,
            segment_lengths=Tuple(node.leaflet_segment_lengths),
            segment_widths=Tuple(node.leaflet_segment_widths),
        ) for node in leaflets
    )

    return (
        counts=(
            Petiole=count(node -> symbol(node) == :Petiole, nodes),
            PetioleSegment=count(
                node -> symbol(node) == :PetioleSegment,
                nodes,
            ),
            Rachis=count(node -> symbol(node) == :Rachis, nodes),
            RachisSegment=count(
                node -> symbol(node) == :RachisSegment,
                nodes,
            ),
            Leaflet=length(leaflets),
        ),
        root=(id=node_id(leaf), parent_id=node_id(parent(leaf))),
        identities=(
            petiole=node_id(petiole),
            rachis=node_id(rachis),
            leaflets=Tuple(node_id.(leaflets)),
        ),
        parents=bytes2hex(SHA.sha256(repr(parents))),
        leaflet_local=bytes2hex(SHA.sha256(repr(leaflet_local))),
    )
end

function _vpalm_freeze_dynamic_attribute(value)
    if value isa AbstractDict
        names = sort!(collect(keys(value)); by=string)
        return Tuple(
            name => _vpalm_freeze_dynamic_attribute(value[name])
            for name in names
        )
    elseif value isa NamedTuple
        return Tuple(
            name => _vpalm_freeze_dynamic_attribute(getproperty(value, name))
            for name in propertynames(value)
        )
    elseif value isa AbstractArray || value isa Tuple
        return Tuple(_vpalm_freeze_dynamic_attribute(item) for item in value)
    elseif value isa Pair
        return _vpalm_freeze_dynamic_attribute(first(value)) =>
               _vpalm_freeze_dynamic_attribute(last(value))
    end
    return value
end

function _vpalm_dynamic_architecture_fingerprint(seed, steps)
    parameters = XPalm.default_parameters()
    parameters["vpalm"]["seed"] = seed
    palm = Palm(
        initiation_age=0,
        parameters=parameters,
        architecture=true,
    )
    scene = XPalm.xpalm_scene(
        palm;
        architecture=true,
        environment=first(meteo, steps),
    )
    run!(scene; steps=steps, outputs=:none)

    nodes = Any[]
    traverse!(palm.mtg) do node
        push!(nodes, node)
        return nothing
    end
    sort!(nodes; by=node_id)

    io = IOBuffer()
    class_counts = Dict{Symbol,Int}()
    for node in nodes
        node_class = symbol(node)
        class_counts[node_class] = get(class_counts, node_class, 0) + 1
        parent_node = parent(node)
        print(
            io,
            node_id(node),
            '|',
            node_class,
            '|',
            index(node),
            '|',
            scale(node),
            '|',
            MultiScaleTreeGraph.link(node),
            '|',
            isnothing(parent_node) ? 0 : node_id(parent_node),
        )
        # Configuration and RNG containers encode the requested seed directly.
        # Excluding them makes the different-seed assertion depend on the
        # resulting botanical state rather than on its input metadata.
        ignored_attributes = (:geometry, :parameters, :vpalm_rng)
        attribute_names = sort!(
            filter(name -> name ∉ ignored_attributes, collect(keys(node)));
            by=string,
        )
        for name in attribute_names
            print(
                io,
                '|',
                name,
                '=',
                repr(_vpalm_freeze_dynamic_attribute(node[name])),
            )
        end
        print(io, '\n')
    end

    return (
        nodes=length(nodes),
        classes=Tuple(sort!(collect(class_counts); by=first)),
        sha256=bytes2hex(SHA.sha256(take!(io))),
    )
end

function _vpalm_observer_contract(architecture, parameters, weather, steps)
    palm = Palm(
        initiation_age=0,
        parameters=deepcopy(parameters),
        architecture=architecture,
    )
    scene = XPalm.xpalm_scene(
        palm;
        architecture=architecture,
        environment=weather,
    )
    simulation = run!(
        scene;
        steps=steps,
        outputs=[
            OutputRequest(:Scene, :lai),
            OutputRequest(:Scene, :leaf_area),
            OutputRequest(:Plant, :carbon_assimilation),
        ],
    )

    values(name) = Tuple(
        row.value for row in collect_outputs(simulation, name; sink=nothing)
    )
    return (
        lai=values(:lai),
        leaf_area=values(:leaf_area),
        carbon_assimilation=values(:carbon_assimilation),
    )
end

@testset "dynamic leaf update preserves geometry identity" begin
    parameters = VPalm.default_parameters(type="dynamic")
    visible_rank = VPalm.first_visible_leaf_rank(parameters)
    @test VPalm.is_visible_leaf_rank(visible_rank, parameters)

    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    leaf = Node(2, plant, NodeMTG(:+, :Leaf, 1, 4), Dict{Symbol,Any}())
    unique_id = Ref(3)
    rng = StableRNG(20260830)
    VPalm.leaf(
        unique_id,
        1,
        visible_rank,
        2.0u"kg",
        3.0u"m",
        leaf,
        parameters;
        rng=rng,
    )

    petiole = only(descendants(leaf; symbol=:Petiole))
    rachis = only(descendants(leaf; symbol=:Rachis))
    leaflets = sort(descendants(leaf; symbol=:Leaflet); by=node_id)
    before = _vpalm_leaf_geometry_fingerprint(leaf)
    leaflet_angles_before = Tuple(
        (node.zenithal_angle, node.azimuthal_angle) for node in leaflets
    )

    @test before.counts == (
        Petiole=1,
        PetioleSegment=parameters["petiole_nb_segments"],
        Rachis=1,
        RachisSegment=parameters["rachis_nb_segments"],
        Leaflet=length(leaflets),
    )
    @test before.counts.Leaflet > 0
    @test all(parent(node) !== nothing for node in descendants(leaf))

    leaf.rank = 2
    VPalm.compute_properties_leaf!(leaf, leaf.rank, 4.0u"m", parameters, rng)
    VPalm.update_leaf!(leaf, 4.0u"kg", parameters; rng=rng)

    petiole_after = only(descendants(leaf; symbol=:Petiole))
    rachis_after = only(descendants(leaf; symbol=:Rachis))
    leaflets_after = sort(descendants(leaf; symbol=:Leaflet); by=node_id)
    after = _vpalm_leaf_geometry_fingerprint(leaf)
    leaflet_angles_after = Tuple(
        (node.zenithal_angle, node.azimuthal_angle) for node in leaflets_after
    )

    @test after == before
    @test petiole_after === petiole
    @test rachis_after === rachis
    @test length(leaflets_after) == length(leaflets)
    @test all(
        leaflets_after[i] === leaflets[i] for i in eachindex(leaflets)
    )
    @test leaflet_angles_after != leaflet_angles_before
end

@testset "pruning retains only the snag leaf" begin
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
    leaf_id = node_id(leaf)
    leaf_parent = parent(leaf)
    geometry_scales = (
        :Petiole,
        :PetioleSegment,
        :Rachis,
        :RachisSegment,
        :Leaflet,
    )
    @test all(
        !isempty(descendants(leaf; symbol=class)) for class in geometry_scales
    )

    leaf_object.status.is_pruned = true
    run!(scene; steps=1, outputs=:none)

    @test get_node(palm.mtg, leaf_id) === leaf
    @test parent(leaf) === leaf_parent
    @test only(children(internode)) === leaf
    @test !leaf.is_alive
    @test isempty(descendants(leaf))
    @test all(
        isempty(descendants(leaf; symbol=class)) for class in geometry_scales
    )
    @test any(
        object -> PlantSimEngine.source_node(scene, object) === leaf,
        model_objects(scene; scale=:Leaf),
    )

    refmesh_cylinder = PlantGeom.RefMesh(
        "geometry-contract-cylinder",
        GeometryBasics.mesh(VPalm.cylinder()),
    )
    VPalm.add_geometry!(internode, refmesh_cylinder)
    @test leaf.geometry isa PlantGeom.ExtrudedTubeGeometry
end

@testset "architecture observers remain exact" begin
    steps = 3
    parameters = XPalm.default_parameters()
    parameters["vpalm"]["seed"] = 20260830
    weather = first(meteo, steps)

    without_architecture = _vpalm_observer_contract(
        false,
        parameters,
        weather,
        steps,
    )
    with_architecture = _vpalm_observer_contract(
        true,
        parameters,
        weather,
        steps,
    )

    @test length(with_architecture.lai) == steps
    @test length(with_architecture.leaf_area) == steps
    @test length(with_architecture.carbon_assimilation) == steps
    @test with_architecture == without_architecture
end


@testset "dynamic architecture is deterministic for a fixed seed" begin
    # Event-driven geometry intentionally treats stochastic angles as organ
    # traits: random draws occur at construction or a real rank transition,
    # not on every no-change day. This pairwise full-MTG fingerprint is the
    # determinism contract for the resulting topology and botanical state.
    steps = 180
    first_run = _vpalm_dynamic_architecture_fingerprint(20260830, steps)
    repeated_run = _vpalm_dynamic_architecture_fingerprint(20260830, steps)
    different_seed = _vpalm_dynamic_architecture_fingerprint(20260831, steps)

    @test first_run == repeated_run
    @test first_run.nodes > 1_000
    @test first_run.sha256 != different_seed.sha256
end
