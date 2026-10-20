module AnnualFruitPanelRed

using CSV, DataFrames, Dates, SHA, TOML
import CairoMakie as C

const SOURCE = "/Users/rvezy/Documents/dev/XPalm_calibration_new/2-results/catchup_demand_20261004"
const ORIGINAL_PLOT_SOURCE = "/Users/rvezy/Documents/dev/XPalm_calibration_new/src/presentation_panels.jl"
const OUTPUT = joinpath(@__DIR__, "annual_fruit")
const CASES = ("reference", "catchup")
const COLORS = ("#777777", "#009E73")
const OBSERVED = "#D62728"

digest(path) = open(io -> bytes2hex(sha256(io)), path)

"""Sum allocation-funded fruit growth and observed targets by observed harvest year.

This is the same cohort aggregation as XPalmCatchUpPresentation. The values exclude
external corrections applied at harvest and cover only the 50 measured PR bunches.
"""
function annual_cohorts(cohorts)
    table = transform(cohorts, :harvest_date => ByRow(year) => :year)
    annual = combine(groupby(table, :year),
        :allocation_funded_fruit_kg => sum => :funded_fruit_dry_kg,
        :observed_fruit_dry_kg => sum => :observed_fruit_dry_kg,
        :uid => length => :measured_bunches)
    sort!(annual, :year)
end

"""Render the single annual fruit panel with red observed points, from saved data.

No simulation is rerun and no model parameters are changed. Execute through the
project's Kaimon session: include(this_file); AnnualFruitPanelRed.render().
"""
function render(; output = OUTPUT)
    mkpath(output)
    inputs = [joinpath(SOURCE, "CHECKS.toml"),
        joinpath(SOURCE, "annual_fruit_stalk_comparison.csv"),
        ORIGINAL_PLOT_SOURCE,
        @__FILE__]
    @assert TOML.parsefile(inputs[1])["passed"]
    cohorts = Dict{String,DataFrame}()
    annual = Dict{String,DataFrame}()
    for case in CASES
        path = joinpath(SOURCE, case, "cohorts.csv")
        push!(inputs, path)
        cohorts[case] = CSV.read(path, DataFrame; ntasks = 1,
            types = Dict(:harvest_date => Date))
        sort!(cohorts[case], [:harvest_date, :uid])
        @assert nrow(cohorts[case]) == 50
        @assert length(unique(cohorts[case].uid)) == 50
        @assert all(==("PR"), cohorts[case].site)
        @assert length(unique(cohorts[case].tree)) == 1
        annual[case] = annual_cohorts(cohorts[case])
        @assert annual[case].year == collect(2014:2022)
        @assert all(isfinite, annual[case].funded_fruit_dry_kg)
    end
    identities = [:uid, :harvest_date, :observed_fruit_dry_kg]
    @assert isequal(cohorts["reference"][:, identities],
        cohorts["catchup"][:, identities])
    @assert annual["reference"].observed_fruit_dry_kg ==
        annual["catchup"].observed_fruit_dry_kg

    # Also verify the recomputation against the archived annual table.
    archived = CSV.read(joinpath(SOURCE, "annual_fruit_stalk_comparison.csv"),
        DataFrame; ntasks = 1)
    for case in CASES
        saved = sort(filter(:treatment => ==(case), archived), :year)
        @assert saved.year == annual[case].year
        for column in (:funded_fruit_dry_kg, :observed_fruit_dry_kg)
            @assert all(isapprox.(saved[!, column], annual[case][!, column];
                atol = 1e-10, rtol = 1e-12))
        end
    end
    input_hashes = Dict(path => digest(path) for path in inputs)

    # Keep the axis styling of the original three-panel Makie figure. The
    # standalone canvas replaces the previous manual crop; it adds no legend.
    fig = C.Figure(size = (600, 470), fontsize = 19,
        figure_padding = (24, 18, 10, 8))
    fruit = C.Axis(fig[1, 1];
        title = "Fruit dry mass",
        ylabel = "Allocated dry mass (kg/palm/year)",
        xlabel = "Harvest year", xticks = 2014:2:2022,
        titlesize = 21, xlabelsize = 19, ylabelsize = 18,
        xticklabelsize = 17, yticklabelsize = 17)
    for (i, case) in enumerate(CASES)
        table = annual[case]
        C.scatterlines!(fruit, table.year, table.funded_fruit_dry_kg;
            color = COLORS[i], linewidth = 3.5, markersize = 8)
    end
    # Draw observed endpoints last so their red markers remain visible even
    # when catch-up growth almost reaches the measured target.
    observed = annual["reference"]
    C.scatter!(fruit, observed.year, observed.observed_fruit_dry_kg;
        color = OBSERVED, markersize = 11)
    C.ylims!(fruit, 0, nothing)

    stem = joinpath(output, "fruit_dry_mass_red_observations")
    png, svg, pdf = stem * ".png", stem * ".svg", stem * ".pdf"
    C.save(png, fig; px_per_unit = 2)
    C.save(svg, fig)
    C.save(pdf, fig)
    values = vcat([transform(annual[case],
        :year => ByRow(_ -> case) => :treatment) for case in CASES]...)
    csv = joinpath(output, "annual_fruit_dry_mass_values.csv")
    CSV.write(csv, values)
    @assert all(digest(path) == hash for (path, hash) in input_hashes)
    outputs = [png, svg, pdf, csv]
    checks = Dict(
        "passed" => true,
        "saved_inputs_unchanged" => true,
        "same_observed_targets_and_harvest_dates" => true,
        "archived_annual_values_reproduced" => true,
        "measured_bunches" => 50,
        "years" => collect(2014:2022),
        "figure_size_px" => [1200, 940],
        "observed_marker_color" => OBSERVED,
        "observed_fruit_dry_mass_total_kg" => sum(observed.observed_fruit_dry_kg),
        "reference_allocated_fruit_dry_mass_total_kg" => sum(annual["reference"].funded_fruit_dry_kg),
        "catchup_allocated_fruit_dry_mass_total_kg" => sum(annual["catchup"].funded_fruit_dry_kg),
        "scope" => "Conditional PR diagnostic; 50 measured bunches only; fruit growth before external harvest correction; observed targets and dates fixed; RUE unchanged",
        "source_hashes" => input_hashes,
        "output_hashes" => Dict(path => digest(path) for path in outputs))
    open(joinpath(output, "FIGURE_CHECKS.toml"), "w") do io
        TOML.print(io, checks)
    end
    write(joinpath(output, "README.md"),
        "# Annual fruit dry mass panel\n\n" *
        "Regenerated in Julia/CairoMakie from the saved reference and catch-up cohort tables. " *
        "Grey: fixed daily growth schedule. Green: scheduled growth plus catch-up. " *
        "Red: observed final fruit dry-mass targets.\n\n" *
        "Each annual value is the sum for the same 50 measured PR bunches grouped by observed harvest year. " *
        "Simulated masses are financed by allocation and exclude external corrections at harvest. " *
        "This is a conditional diagnostic with observed targets and harvest dates fixed and unchanged RUE; " *
        "it does not represent an independent annual-yield evaluation.\n\n" *
        "Source: `../annual_fruit_panel_red.jl`. Values and source/output checksums are included.\n")
    (; png, svg, pdf, csv, measured_bunches = 50, years = (2014, 2022),
        observed_total_kg = checks["observed_fruit_dry_mass_total_kg"],
        reference_total_kg = checks["reference_allocated_fruit_dry_mass_total_kg"],
        catchup_total_kg = checks["catchup_allocated_fruit_dry_mass_total_kg"])
end

end
