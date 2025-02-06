mtg_ref = joinpath(dirname(dirname(pathof(XPalmModel))), "test/references/palm.mtg")
# Write the reference:
# @edit MultiScaleTreeGraph.write_mtg(mtg_ref, select(Palm().mtg, :initiation_age))

@testset "Palm initialisation" begin
    ref_mtg = MultiScaleTreeGraph.read_mtg(mtg_ref, Dict, MultiScaleTreeGraph.NodeMTG)
    new_palm = XPalmModel.Palm()

    @test select(new_palm.mtg, :initiation_age) == select(ref_mtg, :initiation_age)
    @test new_palm.initiation_age == 0
    @test typeof(new_palm.parameters) == Dict{Symbol,Any}
    @test new_palm.parameters[:SRL] == 0.4
end