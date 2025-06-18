file = joinpath(dirname(dirname(pathof(VPalm))), "test", "references", "vpalm-parameter_file.yml")
parameters = read_parameters(file)

@testset "static mockup" begin
    mtg = VPalm.mtg_skeleton(parameters)
    nb_leaves_alive = parameters["nb_leaves_mean"]
    nb_leaves = parameters["nb_leaves_emitted"] + parameters["nb_internodes_before_planting"]
    nb_internodes = nb_leaves
    nb_phytomers = nb_internodes
    nb_petioles = nb_leaves_alive
    nb_petiole_sections = parameters["petiole_nb_segments"] * nb_petioles
    nb_rachis = nb_leaves_alive
    nb_rachis_sections = parameters["rachis_nb_segments"] * nb_rachis

    mtg_no_leaflets = MultiScaleTreeGraph.traverse(mtg, node -> node, symbol=["Plant", "Stem", "Phytomer", "Internode", "Leaf", "Petiole", "PetioleSegment", "Rachis", "RachisSegment"])
    @test length(mtg_no_leaflets) == nb_phytomers + nb_internodes + nb_leaves + nb_petioles + nb_petiole_sections + nb_rachis + nb_rachis_sections + 2 # 2 for stem and plant
    # Check the length of the mockup: nb leaves emitted * 3 (phytomer + internode + leaf) + 2 (stem + plant)
    @test typeof(mtg) == MultiScaleTreeGraph.Node{MultiScaleTreeGraph.MutableNodeMTG,Dict{Symbol,Any}}
    @test mtg[1][:stem_bending] == 0.0
end