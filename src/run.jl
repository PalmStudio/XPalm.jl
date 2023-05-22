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
        # Give access to TEff to the roots:
        PlantSimEngine.run!(roots[:models].models.thermal_time, roots[:models], roots[:models].status[i], meteo_, constants, nothing)
        # Give access to TEff to the plant:
        PlantSimEngine.run!(plant[:models].models.thermal_time, plant[:models], plant[:models].status[i], meteo_, constants, nothing)

        # Call the model that gives the age for the plant:
        PlantSimEngine.run!(plant[:models].models.plant_age, plant[:models], plant[:models].status[i], meteo_, constants, nothing)

        # Give access to the ET0 of the scene to the soil:
        PlantSimEngine.run!(soil[:models].models.potential_evapotranspiration, soil[:models].models, soil[:models].status[i], meteo_, constants, soil)

        # Run the water model in the soil:
        PlantSimEngine.run!(soil[:models].models.soil_water, soil[:models].models, soil[:models].status[i], meteo_, constants, nothing)

        # Run the root growth model in the soil (it already knows how to get the ftsw from the soil model):
        PlantSimEngine.run!(roots[:models].models.root_growth, roots[:models].models, roots[:models].status[i], meteo_, constants, roots)

        # Give the ftsw value to the plant:
        PlantSimEngine.run!(plant[:models].models.soil_water, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        # Run models at leaf scale:
        MultiScaleTreeGraph.traverse(plant, symbol="Leaf") do node
            # Propagate initiation age:
            PlantSimEngine.run!(node[:models].models.initiation_age, node[:models], node[:models].status[i], meteo_, constants, nothing)

            # Run the leaf_potential_area model over all leaves:
            PlantSimEngine.run!(node[:models].models.leaf_potential_area, node[:models], node[:models].status[i], meteo_, constants, nothing)
            # Here we re-compute it each day because we need to propagate the value.

            PlantSimEngine.run!(node[:models].models.leaf_area, node[:models], node[:models].status[i], meteo_, constants, nothing)
        end

        # Run the phyllochron model over the plant:
        PlantSimEngine.run!(plant[:models].models.phyllochron, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        # Compute LAI from total leaf area:
        PlantSimEngine.run!(plant[:models].models.lai_dynamic, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)
    end
end