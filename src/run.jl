function run_XPalm(p::Palm, meteo, constants=PlantMeteo.Constants())
    scene = p.mtg
    soil = scene[1]
    plant = scene[2]
    roots = scene[2][1]

    for (i, meteo_) in enumerate(Tables.rows(meteo))
        # Compute the models at the scene scale:
        # ET0:
        PlantSimEngine.run!(scene[:models].models.potential_evapotranspiration, scene[:models], scene[:models].status[i], meteo_, constants, nothing)
        # TEff:
        PlantSimEngine.run!(scene[:models].models.thermal_time, scene[:models], scene[:models].status[i], meteo_, constants, nothing)

        # Give access to the ET0 of the scene to the soil:
        PlantSimEngine.run!(soil[:models].models.potential_evapotranspiration, soil[:models].models, soil[:models].status[i], meteo_, constants, soil)

        # Run the water model in the soil:
        PlantSimEngine.run!(soil[:models].models.soil_water, soil[:models].models, soil[:models].status[i], meteo_, constants, nothing)

        # Five access to TEff to the roots:
        PlantSimEngine.run!(roots[:models].models.thermal_time, roots[:models], roots[:models].status[i], meteo_, constants, nothing)
        # Run the root growth model in the soil (it already knows how to get the ftsw from the soil model):
        PlantSimEngine.run!(roots[:models].models.root_growth, roots[:models].models, roots[:models].status[i], meteo_, constants, roots)

        # Run the leaf_potential_area model over all leaves:
        MultiScaleTreeGraph.traverse(plant, symbol="Leaf") do node
            PlantSimEngine.run!(node[:models].models.leaf_potential_area, node[:models], node[:models].status[i], meteo_, constants, nothing)
        end
        #! note: only the last leaf should be computed here. Or maybe this computation should only be done at leaf emission.
    end
end