function run_XPalm(p::Palm, meteo, constants=PlantMeteo.Constants())
    scene = p.mtg
    soil = scene[1]
    plant = scene[2]
    stem = plant[2]
    roots = plant[1]

    for (i, meteo_) in enumerate(Tables.rows(meteo))
        # Compute the models at the scene scale:
        # ET0:
        PlantSimEngine.run!(scene[:models].models.potential_evapotranspiration, scene[:models].models, scene[:models].status[i], meteo_, constants, nothing)
        # TEff:
        PlantSimEngine.run!(scene[:models].models.thermal_time, scene[:models].models, scene[:models].status[i], meteo_, constants, nothing)
        # Give access to TEff to the roots:
        PlantSimEngine.run!(roots[:models].models.thermal_time, roots[:models].models, roots[:models].status[i], meteo_, constants, nothing)
        # Give access to TEff to the plant:
        PlantSimEngine.run!(plant[:models].models.thermal_time, plant[:models].models, plant[:models].status[i], meteo_, constants, nothing)

        # Propagate the lai from the day before to the current day:
        PlantSimEngine.run!(scene[:models].models.lai_dynamic, scene[:models].models, scene[:models].status[i], meteo_, constants, nothing)

        # Call the model that propagates the value of the rank to the next day:
        MultiScaleTreeGraph.traverse!(plant, symbol="Phytomer") do phytomer
            PlantSimEngine.run!(phytomer[:models].models.leaf_rank, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, nothing)
        end

        # Call the model that gives the age for the plant:
        PlantSimEngine.run!(plant[:models].models.plant_age, plant[:models].models, plant[:models].status[i], meteo_, constants, nothing)

        # Give access to the ET0 of the scene to the soil:
        PlantSimEngine.run!(soil[:models].models.potential_evapotranspiration, soil[:models].models, soil[:models].status[i], meteo_, constants, soil)

        # Light interception at the scene scale:
        PlantSimEngine.run!(scene[:models].models.light_interception, scene[:models].models, scene[:models].status[i], meteo_, constants)
        # Give the light interception to the plants:
        PlantSimEngine.run!(plant[:models].models.light_interception, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)
        # And to the soil:
        PlantSimEngine.run!(soil[:models].models.light_interception, soil[:models].models, soil[:models].status[i], meteo_, constants, soil)

        # Run the water model in the soil:
        PlantSimEngine.run!(soil[:models].models.soil_water, soil[:models].models, soil[:models].status[i], meteo_, constants, nothing)

        # Give the value of ftsw to the roots:
        PlantSimEngine.run!(roots[:models].models.soil_water, roots[:models].models, roots[:models].status[i], meteo_, constants, roots)

        # Run the root growth model in the soil (it already knows how to get the ftsw from the soil model):
        PlantSimEngine.run!(roots[:models].models.root_growth, roots[:models].models, roots[:models].status[i], meteo_, constants, nothing)

        # Give the value of root_depth to the soil:
        PlantSimEngine.run!(soil[:models].models.root_growth, soil[:models].models, soil[:models].status[i], meteo_, constants, soil)

        # Give the ftsw value to the plant:
        PlantSimEngine.run!(plant[:models].models.soil_water, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        # Carbon assimilation:
        PlantSimEngine.run!(plant[:models].models.carbon_assimilation, plant[:models].models, plant[:models].status[i], meteo_, constants)

        # Maintenance respiration:
        PlantSimEngine.run!(plant[:models].models.maintenance_respiration, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        # Carbon offer:
        PlantSimEngine.run!(plant[:models].models.carbon_offer, plant[:models].models, plant[:models].status[i], meteo_, constants, nothing)

        # Compute models for the internodes:
        MultiScaleTreeGraph.traverse!(plant, symbol="Internode") do internode
            PlantSimEngine.run!(internode[:models].models.soil_water, internode[:models].models, internode[:models].status[i], meteo_, constants, internode)
            # Thermal time since initiation:
            PlantSimEngine.run!(internode[:models].models.thermal_time, internode[:models].models, internode[:models].status[i], meteo_, constants, internode)
            # Propagate initiation age:
            PlantSimEngine.run!(internode[:models].models.initiation_age, internode[:models].models, internode[:models].status[i], meteo_, constants, nothing)
            PlantSimEngine.run!(internode[:models].models.internode_final_potential_dimensions, internode[:models].models, internode[:models].status[i], meteo_, constants, internode)
            PlantSimEngine.run!(internode[:models].models.internode_potential_dimensions, internode[:models].models, internode[:models].status[i], meteo_, constants, internode)
            PlantSimEngine.run!(internode[:models].models.carbon_demand, internode[:models].models, internode[:models].status[i], meteo_, constants, internode)
        end

        # Run models at leaf scale:
        MultiScaleTreeGraph.traverse!(plant, symbol="Leaf") do leaf
            # Give the ftsw value to the leaf:
            PlantSimEngine.run!(leaf[:models].models.soil_water, leaf[:models].models, leaf[:models].status[i], meteo_, constants, leaf)

            # Propagate initiation age:
            PlantSimEngine.run!(leaf[:models].models.initiation_age, leaf[:models].models, leaf[:models].status[i], meteo_, constants, nothing)
            # Thermal time since initiation:
            PlantSimEngine.run!(leaf[:models].models.thermal_time, leaf[:models].models, leaf[:models].status[i], meteo_, constants, leaf)

            PlantSimEngine.run!(leaf[:models].models.leaf_final_potential_area, leaf[:models].models, leaf[:models].status[i], meteo_, constants, leaf)
            # Run the leaf_potential_area model over all leaves:
            PlantSimEngine.run!(leaf[:models].models.leaf_potential_area, leaf[:models].models, leaf[:models].status[i], meteo_, constants, nothing)

            PlantSimEngine.run!(leaf[:models].models.state, leaf[:models].models, leaf[:models].status[i], meteo_, constants, leaf)
            PlantSimEngine.run!(leaf[:models].models.carbon_demand, leaf[:models].models, leaf[:models].status[i], meteo_, constants, nothing)
        end

        # sum the leaves carbon demand at the plant scale:
        # PlantSimEngine.run!(plant[:models].models.carbon_demand, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)
        # note: update to a full model when several organs are computed for the carbon demand here.

        # Compute models for the Male inflorescences:
        MultiScaleTreeGraph.traverse!(plant, symbol="Male") do male
            PlantSimEngine.run!(male[:models].models.soil_water, male[:models].models, male[:models].status[i], meteo_, constants, male)
            # Thermal time since initiation:
            PlantSimEngine.run!(male[:models].models.thermal_time, male[:models].models, male[:models].status[i], meteo_, constants, male)
            # Propagate initiation age:
            PlantSimEngine.run!(male[:models].models.initiation_age, male[:models].models, male[:models].status[i], meteo_, constants, nothing)
            PlantSimEngine.run!(male[:models].models.final_potential_biomass, male[:models].models, male[:models].status[i], meteo_, constants, nothing)
            PlantSimEngine.run!(male[:models].models.carbon_demand, male[:models].models, male[:models].status[i], meteo_, constants, male)
        end

        MultiScaleTreeGraph.traverse!(plant, symbol="Female") do female
            PlantSimEngine.run!(female[:models].models.soil_water, female[:models].models, female[:models].status[i], meteo_, constants, female)
            # Thermal time since initiation:
            PlantSimEngine.run!(female[:models].models.thermal_time, female[:models].models, female[:models].status[i], meteo_, constants, female)
            # Propagate initiation age:
            PlantSimEngine.run!(female[:models].models.initiation_age, female[:models].models, female[:models].status[i], meteo_, constants, nothing)
            PlantSimEngine.run!(female[:models].models.final_potential_biomass, female[:models].models, female[:models].status[i], meteo_, constants, nothing)
            PlantSimEngine.run!(female[:models].models.number_spikelets, female[:models].models, female[:models].status[i], meteo_, constants, female)
            PlantSimEngine.run!(female[:models].models.number_fruits, female[:models].models, female[:models].status[i], meteo_, constants, female)
            PlantSimEngine.run!(female[:models].models.carbon_demand, female[:models].models, female[:models].status[i], meteo_, constants, nothing)
        end

        # Compute the carbon allocation to the organs:
        PlantSimEngine.run!(plant[:models].models.carbon_allocation, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        MultiScaleTreeGraph.traverse!(plant, symbol="Internode") do internode
            PlantSimEngine.run!(internode[:models].models.biomass, internode[:models].models, internode[:models].status[i], meteo_, constants, internode)
            PlantSimEngine.run!(internode[:models].models.internode_dimensions, internode[:models].models, internode[:models].status[i], meteo_, constants, nothing)
        end

        # Sum the internode biomass into the stem:
        PlantSimEngine.run!(stem[:models].models.biomass, stem[:models].models, stem[:models].status[i], meteo_, constants, stem)

        MultiScaleTreeGraph.traverse!(plant, symbol="Leaf") do leaf
            PlantSimEngine.run!(leaf[:models].models.biomass, leaf[:models].models, leaf[:models].status[i], meteo_, constants, nothing)
            PlantSimEngine.run!(leaf[:models].models.leaf_area, leaf[:models].models, leaf[:models].status[i], meteo_, constants, nothing)
        end

        MultiScaleTreeGraph.traverse!(plant, symbol=["Male", "Female"]) do organ
            PlantSimEngine.run!(organ[:models].models.biomass, organ[:models].models, organ[:models].status[i], meteo_, constants, nothing)
        end

        PlantSimEngine.run!(plant[:models].models.biomass, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)
        PlantSimEngine.run!(plant[:models].models.reserve_filling, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        MultiScaleTreeGraph.traverse!(plant, symbol="Phytomer") do phytomer
            #! these models only go and get the values from other scales:
            # Give the ftsw value to the phytomer:
            PlantSimEngine.run!(phytomer[:models].models.soil_water, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, phytomer)
            PlantSimEngine.run!(phytomer[:models].models.carbon_offer, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, phytomer)
            PlantSimEngine.run!(phytomer[:models].models.carbon_allocation, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, phytomer)
            #! end of comment above

            # Thermal time since initiation:
            PlantSimEngine.run!(phytomer[:models].models.thermal_time, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, phytomer)
            PlantSimEngine.run!(phytomer[:models].models.initiation_age, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, nothing)
            PlantSimEngine.run!(phytomer[:models].models.sex_determination, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, phytomer)
            PlantSimEngine.run!(phytomer[:models].models.abortion, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, phytomer)
            PlantSimEngine.run!(phytomer[:models].models.state, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, phytomer)
            PlantSimEngine.run!(phytomer[:models].models.leaf_pruning, phytomer[:models].models, phytomer[:models].status[i], meteo_, constants, phytomer)
        end

        # Compute the harvest:
        MultiScaleTreeGraph.traverse!(plant, symbol="Female") do female
            PlantSimEngine.run!(female[:models].models.harvest, female[:models].models, female[:models].status[i], meteo_, constants, nothing)
        end

        # Run the phyllochron model over the plant (calls phytomer emission):
        PlantSimEngine.run!(plant[:models].models.phyllochron, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        # Compute the plant total leaf area:
        PlantSimEngine.run!(plant[:models].models.leaf_area, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        # Compute the total harvest:
        PlantSimEngine.run!(plant[:models].models.harvest, plant[:models].models, plant[:models].status[i], meteo_, constants, plant)

        # Compute LAI from total leaf area:
        PlantSimEngine.run!(scene[:models].models.lai_dynamic, scene[:models].models, scene[:models].status[i], meteo_, constants, scene)
    end
end