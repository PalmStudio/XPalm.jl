const REFERENCE_REGRESSION_VARIABLES = Dict{Symbol,Any}(
    :Scene => (:lai, :leaf_area, :aPPFD),
    :Plant => (
        :plant_age,
        :leaf_area,
        :aPPFD,
        :Rm,
        :carbon_assimilation,
        :phytomer_count,
        :biomass_bunch_harvested,
        :biomass_bunch_harvested_cum,
        :n_bunches_harvested,
        :n_bunches_harvested_cum,
        :biomass_oil_harvested,
        :biomass_oil_harvested_cum,
    ),
    :Soil => (:ftsw, :root_depth),
)

const REFERENCE_REGRESSION_FLOAT_COLUMNS = (
    :scene_lai,
    :scene_leaf_area,
    :scene_aPPFD,
    :plant_leaf_area,
    :plant_aPPFD,
    :plant_Rm,
    :plant_carbon_assimilation,
    :biomass_bunch_harvested,
    :biomass_bunch_harvested_cum,
    :biomass_oil_harvested,
    :biomass_oil_harvested_cum,
    :soil_ftsw,
    :soil_root_depth,
)

const REFERENCE_REGRESSION_EXACT_COLUMNS = (
    :date,
    :timestep,
    :plant_age,
    :phytomer_count,
    :n_bunches_harvested,
    :n_bunches_harvested_cum,
)

function run_reference_regression_scenario(; meteo_path=joinpath(
    dirname(dirname(pathof(XPalm))),
    "0-data",
    "meteo.csv",
))
    meteo = CSV.read(meteo_path, DataFrame)
    :duration in propertynames(meteo) ||
        (meteo.duration = fill(Dates.Day(1), nrow(meteo)))

    elapsed = @elapsed outputs = XPalm.xpalm(
        meteo,
        DataFrame;
        vars=REFERENCE_REGRESSION_VARIABLES,
        architecture=false,
        palm=XPalm.Palm(
            initiation_age=0,
            parameters=XPalm.default_parameters(),
        ),
    )

    return (
        meteo=meteo,
        outputs=outputs,
        tables=reference_regression_tables(outputs, meteo),
        elapsed=elapsed,
    )
end

function reference_regression_daily(outputs, meteo)
    scene = outputs[:Scene]
    plant = outputs[:Plant]
    soil = outputs[:Soil]
    nsteps = nrow(meteo)

    nrow(scene) == nsteps ||
        error("Expected one Scene row per timestep, got $(nrow(scene)) for $nsteps steps.")
    nrow(plant) == nsteps ||
        error("Expected one Plant row per timestep, got $(nrow(plant)) for $nsteps steps.")
    nrow(soil) == nsteps ||
        error("Expected one Soil row per timestep, got $(nrow(soil)) for $nsteps steps.")

    return DataFrame(
        date=meteo.date,
        timestep=plant.timestep,
        plant_age=plant.plant_age,
        phytomer_count=plant.phytomer_count,
        scene_lai=scene.lai,
        scene_leaf_area=scene.leaf_area,
        scene_aPPFD=scene.aPPFD,
        plant_leaf_area=plant.leaf_area,
        plant_aPPFD=plant.aPPFD,
        plant_Rm=plant.Rm,
        plant_carbon_assimilation=plant.carbon_assimilation,
        biomass_bunch_harvested=plant.biomass_bunch_harvested,
        biomass_bunch_harvested_cum=plant.biomass_bunch_harvested_cum,
        n_bunches_harvested=plant.n_bunches_harvested,
        n_bunches_harvested_cum=plant.n_bunches_harvested_cum,
        biomass_oil_harvested=plant.biomass_oil_harvested,
        biomass_oil_harvested_cum=plant.biomass_oil_harvested_cum,
        soil_ftsw=soil.ftsw,
        soil_root_depth=soil.root_depth,
    )
end

function reference_regression_checkpoint_indices(dates)
    indices = Int[1]
    append!(indices, findall(date -> Dates.day(date) == 1, dates))
    push!(indices, length(dates))
    return sort!(unique!(indices))
end

function reference_regression_tables(outputs, meteo)
    daily = reference_regression_daily(outputs, meteo)
    checkpoint_indices = reference_regression_checkpoint_indices(daily.date)
    trajectory = daily[checkpoint_indices, :]
    event_mask =
        (daily.n_bunches_harvested .> 0) .|
        (daily.biomass_bunch_harvested .> 0)
    harvest_events = daily[
        event_mask,
        [
            :date,
            :timestep,
            :biomass_bunch_harvested,
            :biomass_bunch_harvested_cum,
            :n_bunches_harvested,
            :n_bunches_harvested_cum,
            :biomass_oil_harvested,
            :biomass_oil_harvested_cum,
        ],
    ]
    summary = DataFrame(
        nsteps=nrow(daily),
        start_date=first(daily.date),
        end_date=last(daily.date),
        final_lai=last(daily.scene_lai),
        maximum_lai=maximum(daily.scene_lai),
        final_leaf_area=last(daily.plant_leaf_area),
        final_ftsw=last(daily.soil_ftsw),
        minimum_ftsw=minimum(daily.soil_ftsw),
        maximum_ftsw=maximum(daily.soil_ftsw),
        final_root_depth=last(daily.soil_root_depth),
        harvest_event_days=count(event_mask),
        final_bunch_count=last(daily.n_bunches_harvested_cum),
        total_bunch_yield=sum(daily.biomass_bunch_harvested),
        final_cumulative_bunch_yield=last(daily.biomass_bunch_harvested_cum),
        total_oil_yield=sum(daily.biomass_oil_harvested),
        final_cumulative_oil_yield=last(daily.biomass_oil_harvested_cum),
        maximum_daily_bunch_yield=maximum(daily.biomass_bunch_harvested),
        final_phytomer_count=last(daily.phytomer_count),
    )

    return (
        daily=daily,
        trajectory=trajectory,
        harvest_events=harvest_events,
        summary=summary,
    )
end
