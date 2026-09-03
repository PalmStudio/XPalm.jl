const REFERENCE_REGRESSION_BASELINE = "v0.7.0-dev"
const REFERENCE_REGRESSION_DIR = joinpath(
    dirtest,
    "references",
    "regression",
    REFERENCE_REGRESSION_BASELINE,
)

function reference_column_mismatches(current, reference; rtol=1.0e-8, atol=1.0e-8)
    length(current) == length(reference) || return collect(
        1:max(length(current), length(reference)),
    )
    return findall(
        index -> !isapprox(
            current[index],
            reference[index];
            rtol=rtol,
            atol=atol,
            nans=true,
        ),
        eachindex(current),
    )
end

function test_reference_float_columns(
    current,
    reference,
    columns;
    rtol=1.0e-8,
    atol=1.0e-8,
)
    for column in columns
        mismatches = reference_column_mismatches(
            current[!, column],
            reference[!, column];
            rtol=rtol,
            atol=atol,
        )
        if !isempty(mismatches)
            first_mismatch = first(mismatches)
            @info "XPalm reference mismatch" column first_mismatch current_value =
                current[first_mismatch, column] reference_value =
                reference[first_mismatch, column] mismatch_count = length(mismatches)
        end
        @test isempty(mismatches)
    end
end

@testset "XPalm v0.7.0-dev full-cycle numerical regression" begin
    metadata = TOML.parsefile(joinpath(REFERENCE_REGRESSION_DIR, "metadata.toml"))
    meteo_path = joinpath(dirname(dirname(pathof(XPalm))), "0-data", "meteo.csv")
    current_meteo_sha256 = bytes2hex(SHA.sha256(read(meteo_path)))

    @test metadata["source"]["baseline_id"] == REFERENCE_REGRESSION_BASELINE
    @test metadata["source"]["release_state"] == "unreleased"
    @test metadata["source"]["xpalm_version"] == "0.6.1"
    @test metadata["source"]["xpalm_commit"] ==
          "d4ded8891d03f85bb5691b89572a4e003ac6eb7a"
    @test metadata["environment"]["julia_version"] == "1.12.1"
    @test metadata["environment"]["plantsimengine_version"] == "0.15.0"
    @test metadata["environment"]["plantsimengine_commit"] ==
          "82786fba91fad644d8068d75afc64d88282400c4"
    @test metadata["inputs"]["meteo_sha256"] == current_meteo_sha256
    @test metadata["inputs"]["nsteps"] == 4160

    scenario = run_reference_regression_scenario(; meteo_path=meteo_path)
    @test nrow(scenario.meteo) == 4160
    current = scenario.tables
    reference_trajectory =
        CSV.read(
            joinpath(REFERENCE_REGRESSION_DIR, "trajectory_checkpoints.csv"),
            DataFrame;
            types=Dict(:date => Date),
        )
    reference_events =
        CSV.read(
            joinpath(REFERENCE_REGRESSION_DIR, "harvest_events.csv"),
            DataFrame;
            types=Dict(:date => Date),
        )
    reference_summary =
        CSV.read(
            joinpath(REFERENCE_REGRESSION_DIR, "summary.csv"),
            DataFrame;
            types=Dict(:start_date => Date, :end_date => Date),
        )

    @info "XPalm full-cycle numerical regression completed" seconds = scenario.elapsed

    @test names(current.trajectory) == names(reference_trajectory)
    @test nrow(current.trajectory) == nrow(reference_trajectory)
    for column in REFERENCE_REGRESSION_EXACT_COLUMNS
        @test isequal(
            current.trajectory[!, column],
            reference_trajectory[!, column],
        )
    end
    test_reference_float_columns(
        current.trajectory,
        reference_trajectory,
        REFERENCE_REGRESSION_FLOAT_COLUMNS,
    )

    @test names(current.harvest_events) == names(reference_events)
    @test nrow(current.harvest_events) == nrow(reference_events)
    for column in (
        :date,
        :timestep,
        :n_bunches_harvested,
        :n_bunches_harvested_cum,
    )
        @test isequal(
            current.harvest_events[!, column],
            reference_events[!, column],
        )
    end
    test_reference_float_columns(
        current.harvest_events,
        reference_events,
        (
            :biomass_bunch_harvested,
            :biomass_bunch_harvested_cum,
            :biomass_oil_harvested,
            :biomass_oil_harvested_cum,
        ),
    )

    @test names(current.summary) == names(reference_summary)
    for column in (
        :nsteps,
        :start_date,
        :end_date,
        :harvest_event_days,
        :final_bunch_count,
        :final_phytomer_count,
    )
        @test isequal(
            only(current.summary[!, column]),
            only(reference_summary[!, column]),
        )
    end
    test_reference_float_columns(
        current.summary,
        reference_summary,
        (
            :final_lai,
            :maximum_lai,
            :final_leaf_area,
            :final_ftsw,
            :minimum_ftsw,
            :maximum_ftsw,
            :final_root_depth,
            :total_bunch_yield,
            :final_cumulative_bunch_yield,
            :total_oil_yield,
            :final_cumulative_oil_yield,
            :maximum_daily_bunch_yield,
        ),
    )

    daily = current.daily
    @test all(isfinite, daily.scene_lai)
    @test all(isfinite, daily.plant_leaf_area)
    @test all(isfinite, daily.plant_carbon_assimilation)
    @test all(isfinite, daily.soil_ftsw)
    @test all(>=(0.0), daily.scene_lai)
    @test all(>=(0.0), daily.plant_leaf_area)
    @test all(>=(0.0), daily.biomass_bunch_harvested)
    @test all(>=(0.0), daily.biomass_bunch_harvested_cum)
    @test all(diff(daily.biomass_bunch_harvested_cum) .>= -1.0e-8)
    @test minimum(daily.soil_ftsw) >= 0.0
    @test maximum(daily.soil_ftsw) <= 1.01
    @test sum(daily.biomass_bunch_harvested) ≈
          last(daily.biomass_bunch_harvested_cum) rtol = 1.0e-10
    @test sum(daily.biomass_oil_harvested) ≈
          last(daily.biomass_oil_harvested_cum) rtol = 1.0e-10
    @test sum(daily.n_bunches_harvested) ==
          last(daily.n_bunches_harvested_cum)
end
