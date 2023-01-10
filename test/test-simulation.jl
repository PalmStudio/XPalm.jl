@testset "Simulation of a leaf" begin
    p = Palm()
    meteo = Atmosphere(T=25.0, Rh=0.5, Wind=1.0)
    constants = PlantMeteo.Constants()


    node = get_node(p.mtg, 6) # get the leaf node

    # Initialisation of the leaf:
    leaf_status = status(node[:models])[1]
    leaf_status.biomass_dry = 2.0
    leaf_status.temperature = meteo.T

    XPalm.maintenance_respiration!(node[:models], meteo, constants, node)

    @test leaf_status.Rm == 0.0036
end

@testset "Simulation of a Palm" begin
    p = Palm()
    meteo = Atmosphere(T=25.0, Rh=0.5, Wind=1.0)
    constants = PlantMeteo.Constants()

    Rms = MultiScaleTreeGraph.traverse(p.mtg) do node
        # Initialisation of the leaf:
        node_status = status(node[:models])[1]
        hasproperty(node_status, :biomass_dry) && (node_status.biomass_dry = 2.0)
        hasproperty(node_status, :temperature) && (node_status.temperature = meteo.T)
        XPalm.maintenance_respiration!(node[:models], meteo, constants, node)

        return node_status.Rm
    end

    #! to check:
    @test Rms == [-Inf, 0.0012, -Inf, -Inf, 0.0006, 0.0036]
end