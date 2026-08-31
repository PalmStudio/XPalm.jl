
function plot_mockup(parameters)
    # Keep the visual oracle reproducible without suppressing the biologically
    # meaningful high/medium/low variation within leaflet groups.
    mtg = VPalm.build_mockup(
        parameters;
        merge_scale=:leaflet,
        rng=StableRNG(parameters["seed"]),
    )
    traverse!(mtg) do node
        if symbol(node) == :Petiole
            petiole_and_rachis_segments = descendants(node, symbol=[:PetioleSegment, :RachisSegment])
            colormap = cgrad([colorant"peachpuff4", colorant"blanchedalmond"], length(petiole_and_rachis_segments), scale=:log2)
            for (i, seg) in enumerate(petiole_and_rachis_segments)
                seg[:color_type] = colormap[i]
            end
        elseif symbol(node) == :Leaflet
            node[:color_type] = :mediumseagreen
        elseif symbol(node) == :Leaf # This will color the snags
            node[:color_type] = :peachpuff4
        end
    end
    f = Figure(size=(600, 450)) # The reference is 1200x900 px with the default px_per_unit=2.
    ax = LScene(f[1, 1])
    plantviz!(ax, mtg, color=:color_type)

    return f
end

_vpalm_static_meters(value::Unitful.AbstractQuantity) = ustrip(u"m", value)
_vpalm_static_meters(value::Real) = Float64(value)
_vpalm_static_degrees(value::Unitful.AbstractQuantity) = ustrip(u"°", value)
_vpalm_static_degrees(value::Real) = Float64(value)
_vpalm_static_quantize(value::Real) = round(Int64, Float64(value) * 1.0e9)
_vpalm_static_q_m(value) =
    _vpalm_static_quantize(_vpalm_static_meters(value))
_vpalm_static_q_deg(value) =
    _vpalm_static_quantize(_vpalm_static_degrees(value))
_vpalm_static_q_scalar(value) = _vpalm_static_quantize(value)

function _vpalm_static_write_digest_values!(io, values)
    for value in values
        print(io, ':', value)
    end
    return nothing
end

function _vpalm_static_geometry_state_sha256(mtg)
    io = IOBuffer()
    nodes = sort!([mtg; descendants(mtg)]; by=node_id)

    for node in nodes
        class = symbol(node)
        parent_node = parent(node)
        print(
            io,
            node_id(node),
            ':',
            class,
            ':',
            index(node),
            ':',
            isnothing(parent_node) ? 0 : node_id(parent_node),
            ':',
            link(node),
            ':',
            scale(node),
        )

        if class == :Stem
            _vpalm_static_write_digest_values!(
                io,
                (
                    _vpalm_static_q_m(node.stem_height),
                    _vpalm_static_q_m(node.stem_diameter),
                    _vpalm_static_q_deg(node.stem_bending),
                ),
            )
        elseif class == :Internode
            _vpalm_static_write_digest_values!(
                io,
                (
                    node.rank,
                    _vpalm_static_q_m(node.length),
                    _vpalm_static_q_m(node.width),
                    _vpalm_static_q_deg(node.XEuler),
                    _vpalm_static_q_deg(node.Orthotropy),
                ),
            )
        elseif class == :Leaf
            _vpalm_static_write_digest_values!(
                io,
                (node.rank, Int(node.is_alive)),
            )
            if hasproperty(node, :rachis_length)
                _vpalm_static_write_digest_values!(
                    io,
                    (
                        _vpalm_static_q_m(node.rachis_length),
                        _vpalm_static_q_deg(node.zenithal_insertion_angle),
                        _vpalm_static_q_deg(node.zenithal_cpoint_angle),
                    ),
                )
            end
        elseif class == :Petiole
            _vpalm_static_write_digest_values!(
                io,
                (
                    _vpalm_static_q_m(node.length),
                    _vpalm_static_q_m(node.width_base),
                    _vpalm_static_q_m(node.height_base),
                    _vpalm_static_q_m(node.width_cpoint),
                    _vpalm_static_q_m(node.height_cpoint),
                    _vpalm_static_q_deg(node.azimuthal_angle),
                    _vpalm_static_q_deg(node.zenithal_insertion_angle),
                    _vpalm_static_q_deg(node.zenithal_cpoint_angle),
                ),
            )
        elseif class == :PetioleSegment || class == :RachisSegment
            _vpalm_static_write_digest_values!(
                io,
                (
                    _vpalm_static_q_m(node.length),
                    _vpalm_static_q_m(node.width),
                    _vpalm_static_q_m(node.height),
                    _vpalm_static_q_deg(node.zenithal_angle_global),
                    _vpalm_static_q_deg(node.azimuthal_angle_global),
                    _vpalm_static_q_deg(node.torsion_angle_global),
                ),
            )
            if class == :RachisSegment
                _vpalm_static_write_digest_values!(
                    io,
                    (
                        _vpalm_static_q_m(node.x),
                        _vpalm_static_q_m(node.y),
                        _vpalm_static_q_m(node.z),
                    ),
                )
            end
        elseif class == :Leaflet
            _vpalm_static_write_digest_values!(
                io,
                (
                    node.side,
                    node.plane,
                    _vpalm_static_q_m(node.offset),
                    _vpalm_static_q_m(node.length),
                    _vpalm_static_q_m(node.width),
                    _vpalm_static_q_scalar(node.relative_position),
                    _vpalm_static_q_deg(node.zenithal_angle),
                    _vpalm_static_q_deg(node.azimuthal_angle),
                    _vpalm_static_q_deg(node.torsion_angle),
                    _vpalm_static_q_deg(node.lamina_angle),
                ),
            )
            _vpalm_static_write_digest_values!(
                io,
                _vpalm_static_q_m.(node.leaflet_segment_lengths),
            )
            _vpalm_static_write_digest_values!(
                io,
                _vpalm_static_q_m.(node.leaflet_segment_widths),
            )
            _vpalm_static_write_digest_values!(
                io,
                _vpalm_static_q_deg.(node.leaflet_segment_angles_deg),
            )
        end
        write(io, '\n')
    end

    # Quantizing at 1e-9 keeps this cross-platform while protecting the full
    # ordered organ pose and local leaflet profiles without building any mesh.
    return bytes2hex(sha256(take!(io)))
end

function _vpalm_static_reference_fingerprint(mtg)
    classes = (
        :Plant,
        :Stem,
        :Phytomer,
        :Internode,
        :Leaf,
        :Petiole,
        :PetioleSegment,
        :Rachis,
        :RachisSegment,
        :Leaflet,
    )
    class_counts = Dict(class => 0 for class in classes)
    typed_edges = Dict{Tuple{Symbol,Symbol,Symbol},Int}()
    nodes = typeof(mtg)[]
    leaves = typeof(mtg)[]
    petioles = typeof(mtg)[]
    leaflets = typeof(mtg)[]

    traverse!(mtg) do node
        push!(nodes, node)
        class = symbol(node)
        class_counts[class] = get(class_counts, class, 0) + 1
        class == :Leaf && push!(leaves, node)
        class == :Petiole && push!(petioles, node)
        class == :Leaflet && push!(leaflets, node)

        parent_node = parent(node)
        if !isnothing(parent_node)
            edge = (symbol(parent_node), class, link(node))
            typed_edges[edge] = get(typed_edges, edge, 0) + 1
        end
        return nothing
    end

    sorted_edges = sort!(
        collect(typed_edges);
        by=entry -> (
            string(first(entry)[1]),
            string(first(entry)[2]),
            string(first(entry)[3]),
        ),
    )
    edges = Tuple(
        begin
            edge = first(entry)
            (
                parent=edge[1],
                child=edge[2],
                link=edge[3],
                count=last(entry),
            )
        end for entry in sorted_edges
    )

    sort!(nodes; by=node_id)
    sort!(leaves; by=index)
    geometry_leaves = filter(
        leaf -> !isempty(descendants(leaf; symbol=:Rachis)),
        leaves,
    )
    live_leaves = filter(leaf -> leaf.is_alive, leaves)

    return (
        graph=(
            total_nodes=length(mtg),
            first_id=node_id(first(nodes)),
            last_id=node_id(last(nodes)),
            consecutive_ids=node_id.(nodes) == collect(1:length(nodes)),
        ),
        counts=(
            Plant=class_counts[:Plant],
            Stem=class_counts[:Stem],
            Phytomer=class_counts[:Phytomer],
            Internode=class_counts[:Internode],
            Leaf=class_counts[:Leaf],
            Petiole=class_counts[:Petiole],
            PetioleSegment=class_counts[:PetioleSegment],
            Rachis=class_counts[:Rachis],
            RachisSegment=class_counts[:RachisSegment],
            Leaflet=class_counts[:Leaflet],
        ),
        edges,
        leaf_ranks=Tuple(leaf.rank for leaf in leaves),
        geometry_leaf_ranks=Tuple(leaf.rank for leaf in geometry_leaves),
        live_leaf_ranks=Tuple(leaf.rank for leaf in live_leaves),
        leaflet_sides=(
            left=count(leaflet -> leaflet.side == -1, leaflets),
            right=count(leaflet -> leaflet.side == 1, leaflets),
        ),
        dimensions_m=(
            mean_rachis_length=mean(
                _vpalm_static_meters(leaf.rachis_length)
                for leaf in geometry_leaves
            ),
            mean_petiole_length=mean(
                _vpalm_static_meters(petiole.length) for petiole in petioles
            ),
            mean_leaflet_length=mean(
                _vpalm_static_meters(leaflet.length) for leaflet in leaflets
            ),
            mean_leaflet_width=mean(
                _vpalm_static_meters(leaflet.width) for leaflet in leaflets
            ),
        ),
        geometry_state_sha256=_vpalm_static_geometry_state_sha256(mtg),
    )
end

@testset "static mockup" begin
    @testset "seeded leaflet grouping keeps all three planes" begin
        relative_positions = collect(range(0.0, 0.999; length=100))
        frequencies = VPalm.compute_leaflet_type_frequencies(
            vpalm_parameters["leaflet_frequency_high"],
            vpalm_parameters["leaflet_frequency_low"],
        )
        grouped = VPalm.group_leaflets(
            relative_positions,
            frequencies,
            StableRNG(vpalm_parameters["seed"]),
        )
        group_starts = [
            i for i in eachindex(grouped.group) if
            i == firstindex(grouped.group) || grouped.group[i] != grouped.group[i-1]
        ]

        @test sort(unique(grouped.plane)) == [-1, 0, 1]
        @test all(grouped.plane[group_starts] .== 1)
    end

    # Check that the mockup is the same with and without rachis_final_lengths
    mtg = VPalm.mtg_skeleton(vpalm_parameters; rng=StableRNG(vpalm_parameters["seed"]))
    mtg2 = VPalm.mtg_skeleton(vpalm_parameters; rng=StableRNG(vpalm_parameters["seed"]))
    @test mtg == mtg2

    # Check the number of nodes in the mockup
    nb_leaves_alive = length(vpalm_parameters["rachis_fresh_weight"])
    nb_leaves = vpalm_parameters["nb_leaves_emitted"] + vpalm_parameters["nb_internodes_before_planting"]
    nb_internodes = nb_leaves
    nb_phytomers = nb_internodes
    nb_petioles = nb_leaves_alive + vpalm_parameters["nb_leaves_in_sheath"]
    nb_petiole_sections = vpalm_parameters["petiole_nb_segments"] * nb_petioles
    nb_rachis = nb_leaves_alive + vpalm_parameters["nb_leaves_in_sheath"]
    nb_rachis_sections = vpalm_parameters["rachis_nb_segments"] * nb_rachis

    mtg_no_leaflets = MultiScaleTreeGraph.traverse(mtg, node -> node, symbol=[:Plant, :Stem, :Phytomer, :Internode, :Leaf, :Petiole, :PetioleSegment, :Rachis, :RachisSegment])
    @test length(mtg_no_leaflets) == nb_phytomers + nb_internodes + nb_leaves + nb_petioles + nb_petiole_sections + nb_rachis + nb_rachis_sections + 2 # 2 for stem and plant
    # Check the length of the mockup: nb leaves emitted * 3 (phytomer + internode + leaf) + 2 (stem + plant)
    @test mtg isa MultiScaleTreeGraph.Node{MultiScaleTreeGraph.NodeMTG,MultiScaleTreeGraph.ColumnarAttrs}
    @test mtg[1][:stem_bending] == 0.0
end

@testset "deterministic standalone static-120 fingerprint" begin
    parameters = deepcopy(vpalm_parameters)
    parameters["nb_leaves_emitted"] = 120
    mtg = VPalm.mtg_skeleton(
        parameters;
        rng=StableRNG(parameters["seed"]),
    )
    fingerprint = _vpalm_static_reference_fingerprint(mtg)

    @test fingerprint.graph == (
        total_nodes=21263,
        first_id=1,
        last_id=21263,
        consecutive_ids=true,
    )
    @test fingerprint.counts == (
        Plant=1,
        Stem=1,
        Phytomer=140,
        Internode=140,
        Leaf=140,
        Petiole=53,
        PetioleSegment=795,
        Rachis=53,
        RachisSegment=5300,
        Leaflet=14640,
    )
    @test fingerprint.edges == (
        (parent=:Internode, child=:Leaf, link=:+, count=140),
        (parent=:Leaf, child=:Petiole, link=:/, count=53),
        (parent=:Petiole, child=:PetioleSegment, link=:/, count=53),
        (parent=:Petiole, child=:Rachis, link=:<, count=53),
        (
            parent=:PetioleSegment,
            child=:PetioleSegment,
            link=:<,
            count=742,
        ),
        (parent=:Phytomer, child=:Internode, link=:/, count=140),
        (parent=:Phytomer, child=:Phytomer, link=:<, count=139),
        (parent=:Plant, child=:Stem, link=:+, count=1),
        (parent=:Rachis, child=:RachisSegment, link=:/, count=53),
        (parent=:RachisSegment, child=:Leaflet, link=:+, count=14640),
        (
            parent=:RachisSegment,
            child=:RachisSegment,
            link=:<,
            count=5247,
        ),
        (parent=:Stem, child=:Phytomer, link=:/, count=1),
    )
    @test sum(edge.count for edge in fingerprint.edges) ==
          fingerprint.graph.total_nodes - 1
    @test fingerprint.leaf_ranks == Tuple(132:-1:-7)
    @test fingerprint.geometry_leaf_ranks == Tuple(45:-1:-7)
    @test fingerprint.live_leaf_ranks == fingerprint.geometry_leaf_ranks
    @test fingerprint.leaflet_sides == (left=7320, right=7320)
    @test fingerprint.geometry_state_sha256 ==
          "2b5679421c75c194adeb7c50ab55bc4a63839675db1ed6a4031a5b827aa9cdc3"

    expected_dimensions = (
        mean_rachis_length=3.659388011413884,
        mean_petiole_length=0.9307271603974704,
        mean_leaflet_length=0.6122156432448991,
        mean_leaflet_width=0.03293105471072627,
    )
    for name in keys(expected_dimensions)
        @test getproperty(fingerprint.dimensions_m, name) ≈
              getproperty(expected_dimensions, name) rtol = 1.0e-10 atol = 1.0e-12
    end

    # Full-scene mesh materialization is intentionally excluded here: the
    # lightweight mesh contracts exercise bounds and area without rebuilding
    # this 465,302-vertex reference in every static topology test.
end

@testset "static rachis masses follow leaf-rank order" begin
    function two_leaf_mockup(rachis_fresh_weights)
        parameters = deepcopy(vpalm_parameters)
        parameters["nb_leaves_emitted"] = 2
        parameters["nb_internodes_before_planting"] = 0
        parameters["nb_leaves_in_sheath"] = 0
        parameters["rachis_final_lengths"] = fill(3.0u"m", 2)
        parameters["rachis_fresh_weight"] = rachis_fresh_weights
        return VPalm.mtg_skeleton(parameters; rng=nothing)
    end

    function rachis_state(mtg, rank)
        leaf = only(filter(node -> node.rank == rank, descendants(mtg; symbol=:Leaf)))
        return Tuple(
            (
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

    oldest_mass = 3.0u"kg"
    rank_1_mass = 0.5u"kg"
    ordered = two_leaf_mockup([oldest_mass, rank_1_mass])
    all_oldest_mass = two_leaf_mockup(fill(oldest_mass, 2))
    all_rank_1_mass = two_leaf_mockup(fill(rank_1_mass, 2))

    # The first configured mass belongs to the oldest/highest-rank live leaf;
    # the last configured mass belongs to rank 1.
    @test rachis_state(ordered, 2) == rachis_state(all_oldest_mass, 2)
    @test rachis_state(ordered, 1) == rachis_state(all_rank_1_mass, 1)
    @test rachis_state(ordered, 2) != rachis_state(all_rank_1_mass, 2)
    @test rachis_state(ordered, 1) != rachis_state(all_oldest_mass, 1)
end

@testset "static mockup with geometry" begin
    # Check that the mockup with /without geometry are the same
    mtg = VPalm.mtg_skeleton(vpalm_parameters; rng=nothing)
    mtg_geom = VPalm.build_mockup(vpalm_parameters; rng=nothing)
    nb_symbols_mtg = Dict(sym => 0 for sym in get_classes(mtg).SYMBOL)
    traverse!(mtg) do node
        nb_symbols_mtg[symbol(node)] += 1
    end
    nb_symbols_mtg_geom = Dict(sym => 0 for sym in get_classes(mtg_geom).SYMBOL)
    traverse!(mtg_geom) do node
        nb_symbols_mtg_geom[symbol(node)] += 1
    end
    @test nb_symbols_mtg == nb_symbols_mtg_geom
    @test length(mtg) == 20994
    @test length(mtg_geom) == 20994
    @test isempty(descendants(mtg_geom, symbol=:LeafletSegment))

    @test_reference "references/palm_mockup.png" plot_mockup(vpalm_parameters) # delete the file and re-execute interactively to update the reference image
end
