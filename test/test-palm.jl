# Write the reference:
# MultiScaleTreeGraph.write_mtg("references/palm.mtg", select(Palm().mtg, :initiation_day))

@testset "Palm initialisation" begin
    ref_mtg = MultiScaleTreeGraph.read_mtg("references/palm.mtg")
    now = Dates.Date(Dates.now())
    new_palm = Palm(now)

    #! Make this work whenever MTG package is updated:
    # @test select(new_palm.mtg, :initiation_day) == ref_mtg
    @test new_palm.initiation_day == now
    @test new_palm.phytomer_count == 0
    @test new_palm.mtg_node_count == 1
end



p = Palm()
names(p.mtg)

p.mtg[1][:models].models
p.mtg[1][:models].status

root_system = MultiScaleTreeGraph.get_node(p.mtg, 4)
root_system[:models].models

PlantSimEngine.to_initialize(root_system[:models])

status(root_system[:models])[1].nitrogen_content

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
PlantSimEngine.run!(root_system[:models].models.root_growth, root_system[:models].models, status(root_system[:models])[1], meteo, nothing, root_system)



PlantMeteo.rownumber(status(root_system[:models])[1])

MultiScaleTreeGraph.descendants(p.mtg, :models, symbol="Soil")


PlantSimEngine.run!(root_system[:models].models.root_growth, root_system[:models].models, status(root_system[:models])[1], meteo, nothing, root_system)
m = root_system[:models].models.root_growth
models = root_system[:models].models
st = status(root_system[:models])[1]
mtg = root_system
PlantMeteo.prev_value(st, :root_depth; default=m.ini_root_depth)

# Calling FTSW:
@edit PlantSimEngine.run!(models.soil_water, models, st, meteo, nothing, mtg)