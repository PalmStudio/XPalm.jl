const REFERENCE_REGRESSION_BASELINE = REFERENCE_REGRESSION_CANDIDATE_BASELINE
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

@testset "Released v0.7.0 numerical reference is preserved" begin
    # Protect the complete released oracle, including its historical metadata
    # and README. The candidate must not make an intentional behavior change
    # disappear by replacing or relabeling released numerical evidence.
    released = joinpath(dirtest, "references", "regression",
        REFERENCE_REGRESSION_RELEASED_BASELINE)
    expected_hashes = Dict(
        "README.md" => "65f6cf67091042019ef6a7eeac7b92e778daab4cd5fd6e0a937dc74c86d28e3b",
        "harvest_events.csv" => "c887048a8530f5c7834964ace71e2660b8b1a189b275787172da348116522b77",
        "metadata.toml" => "5ae064dc9a20f861b980c2610ce1c95840e7c088d61a71b290503cf1d39eb0c0",
        "summary.csv" => "ea1d0e929b13f379e9924f35d058bd7f895695268004b6603ec1101255df50e0",
        "trajectory_checkpoints.csv" => "5b4b6cdd2bddcf63393810a5bfb825c8081b221517ad8f97decfb3a8edad0b95",
    )
    for (file, expected) in expected_hashes
        @test bytes2hex(SHA.sha256(read(joinpath(released, file)))) == expected
    end
end

@testset "XPalm lifecycle candidate full-cycle numerical regression" begin
    metadata = TOML.parsefile(joinpath(REFERENCE_REGRESSION_DIR, "metadata.toml"))
    meteo_path = joinpath(dirname(dirname(pathof(XPalm))), "0-data", "meteo.csv")
    current_meteo_sha256 = bytes2hex(SHA.sha256(read(meteo_path)))

    @test metadata["source"]["baseline_id"] == REFERENCE_REGRESSION_BASELINE
    @test metadata["source"]["release_state"] == "unreleased"
    @test metadata["source"]["xpalm_version"] == "0.7.0"
    @test metadata["source"]["predecessor_baseline"] == REFERENCE_REGRESSION_RELEASED_BASELINE
    @test metadata["source"]["scientific_change_id"] == REFERENCE_REGRESSION_SCIENTIFIC_CHANGE
    @test metadata["source"]["parameter_source"] == "XPalm.default_parameters()"
    @test occursin(r"^[0-9a-f]{40}$", metadata["source"]["xpalm_commit"])
    @test !isempty(metadata["source"]["scientific_sources_sha256"])
    @test all(value -> occursin(r"^[0-9a-f]{64}$", value),
        values(metadata["source"]["scientific_sources_sha256"]))
    @test VersionNumber(metadata["environment"]["julia_version"]) >= v"1.10"
    @test metadata["environment"]["plantsimengine_version"] == "0.15.0"
    @test metadata["stochastic_configuration"]["sex_determination_seed"] == 1
    @test metadata["stochastic_configuration"]["abortion_seed"] == 1
    @test metadata["inputs"]["meteo_sha256"] == current_meteo_sha256
    @test metadata["inputs"]["nsteps"] == 4160
    @test Set(keys(metadata["fixture"]["csv_sha256"])) == Set(
        ("trajectory_checkpoints.csv", "harvest_events.csv", "summary.csv"),
    )
    for (file, expected) in metadata["fixture"]["csv_sha256"]
        @test bytes2hex(SHA.sha256(read(joinpath(REFERENCE_REGRESSION_DIR, file)))) == expected
    end

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
