# Write the reference:
# MultiScaleTreeGraph.write_mtg("references/palm.mtg", select(Palm().mtg, :initiation_date))

@testset "Palm initialisation" begin
    ref_mtg = MultiScaleTreeGraph.read_mtg("references/palm.mtg")
    now = Dates.Date(Dates.now())
    new_palm = Palm(now)

    #! Make this work whenever MTG package is updated:
    # @test select(new_palm.mtg, :initiation_date) == ref_mtg
    @test new_palm.initiation_date == now
    @test new_palm.phytomer_count == 0
    @test new_palm.mtg_node_count == 1
end