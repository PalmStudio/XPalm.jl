mtg_ref = joinpath(dirname(dirname(pathof(XPalm))), "test/references/palm.mtg")
# Write the reference:
# @edit MultiScaleTreeGraph.write_mtg(mtg_ref, MultiScaleTreeGraph.select(Palm().mtg, :initiation_age))

@testset "Palm initialisation" begin
    ref_mtg = MultiScaleTreeGraph.read_mtg(mtg_ref)
    new_palm = XPalm.Palm()
    new_selected = MultiScaleTreeGraph.select(new_palm.mtg, :initiation_age)
    ref_selected = MultiScaleTreeGraph.select(ref_mtg, :initiation_age)

    # MTG 0.15 no longer defines structural equality between independent graph instances.
    # Compare canonical MTG serialization instead.
    new_mtg_text = mktemp() do path, io
        close(io)
        MultiScaleTreeGraph.write_mtg(path, new_selected)
        read(path, String)
    end
    ref_mtg_text = mktemp() do path, io
        close(io)
        MultiScaleTreeGraph.write_mtg(path, ref_selected)
        read(path, String)
    end

    @test new_mtg_text == ref_mtg_text
    @test new_palm.initiation_age == 0
    @test typeof(new_palm.parameters) == Dict{AbstractString,Any}
    @test new_palm.parameters["mass_and_dimensions"]["roots"]["SRL"] == 0.4
end
