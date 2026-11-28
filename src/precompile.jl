using PrecompileTools: @compile_workload, @setup_workload

@setup_workload begin
    # Exercise the first phytomer and the first reproductive organ with default parameters.
    start = Dates.Date(2025, 1, 1)
    forcing = [
        (date=start + Dates.Day(i), duration=Dates.Day(1),
            T=26.5, Tmin=22.0, Tmax=31.0, Rh=0.7, Rh_min=60.0, Rh_max=95.0,
            Wind=1.0, P=100.0, Rg=16.0, Ri_SW_f=16.0, Ri_PAR_f=8.0,
            Precipitations=3.0 + 0.5 * i)
        for i in 0:1057
    ]

    @compile_workload begin
        palm = Palm(; initiation_age=0, parameters=default_parameters(), architecture=false)
        weather = PlantSimEngine.Weather([PlantSimEngine.Atmosphere(; row...) for row in forcing])
        scene = xpalm_scene(palm; architecture=false, environment=weather)
        simulation = PlantSimEngine.run!(scene; steps=0, outputs=:none, constants=PlantSimEngine.Constants())
        PlantSimEngine.continue!(simulation; steps=length(forcing))
    end
end
