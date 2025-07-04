
function plot_mockup(parameters)
    mtg = build_mockup(parameters; merge_scale=:leaflet)
    traverse!(mtg) do node
        if symbol(node) == "Petiole"
            petiole_and_rachis_segments = descendants(node, symbol=["PetioleSegment", "RachisSegment"])
            colormap = cgrad([colorant"peachpuff4", colorant"blanchedalmond"], length(petiole_and_rachis_segments), scale=:log2)
            for (i, seg) in enumerate(petiole_and_rachis_segments)
                seg[:color_type] = colormap[i]
            end
        elseif symbol(node) == "Leaflet"
            node[:color_type] = :mediumseagreen
        elseif symbol(node) == "Leaf" # This will color the snags
            node[:color_type] = :peachpuff4
        end
    end
f, ax, p = viz(mtg, color=:color_type, size=(1200, 800))
end

@testset "static mockup" begin
    # Check that the mockup is the same with and without rachis_final_lengths
    mtg = VPalm.mtg_skeleton(vpalm_parameters)
    mtg2 = VPalm.mtg_skeleton(vpalm_parameters)
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

    mtg_no_leaflets = MultiScaleTreeGraph.traverse(mtg, node -> node, symbol=["Plant", "Stem", "Phytomer", "Internode", "Leaf", "Petiole", "PetioleSegment", "Rachis", "RachisSegment"])
    @test length(mtg_no_leaflets) == nb_phytomers + nb_internodes + nb_leaves + nb_petioles + nb_petiole_sections + nb_rachis + nb_rachis_sections + 2 # 2 for stem and plant
    # Check the length of the mockup: nb leaves emitted * 3 (phytomer + internode + leaf) + 2 (stem + plant)
    @test typeof(mtg) == MultiScaleTreeGraph.Node{MultiScaleTreeGraph.MutableNodeMTG,Dict{Symbol,Any}}
    @test mtg[1][:stem_bending] == 0.0
end

@testset "static mockup with geometry" begin
    # Check that the mockup with /without geometry are the same
    mtg = VPalm.mtg_skeleton(vpalm_parameters)
    mtg_geom = VPalm.build_mockup(vpalm_parameters)
    nb_symbols_mtg = Dict(sym => 0 for sym in get_classes(mtg).SYMBOL)
    traverse!(mtg) do node
        nb_symbols_mtg[symbol(node)] += 1
    end
    nb_symbols_mtg_geom = Dict(sym => 0 for sym in get_classes(mtg_geom).SYMBOL)
    traverse!(mtg_geom) do node
        nb_symbols_mtg_geom[symbol(node)] += 1
    end
    # we remove the LeafletSegment nodes in the geometry mockup, as it slows the rendering
    @test delete!(nb_symbols_mtg, "LeafletSegment") == nb_symbols_mtg_geom
    @test sum(descendants(mtg, :Length, ignore_nothing = true)) == sum(descendants(mtg_geom, :Length, ignore_nothing = true))

    @test_reference "references/palm_mockup.png" plot_mockup(vpalm_parameters)
end