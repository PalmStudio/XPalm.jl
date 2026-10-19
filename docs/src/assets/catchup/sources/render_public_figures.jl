module XPalmPublicFigureRenderer

using CSV, DataFrames, Printf, SHA, TOML
import CairoMakie as C

const ROOT = normpath(joinpath(@__DIR__, ".."))
const DEFAULT_OUTPUT = joinpath(ROOT, "regenerated_public")
const OLD = "#777777"
const NEW = "#009E73"
const ALLOCATION = "#496B86"
const DEFICIT = "#D55E00"
const OBSERVED = "#D62728"

digest(path) = open(io -> bytes2hex(sha256(io)), path)
fmt(value) = @sprintf("%.2f", value)

function require_columns(table, columns, source)
    missing_columns = setdiff(collect(columns), propertynames(table))
    isempty(missing_columns) || throw(ArgumentError(
        "Missing columns in $(source): $(join(missing_columns, ", "))"))
    return nothing
end

function save_formats(figure, directory, stem)
    mkpath(directory)
    paths = [joinpath(directory, stem * "." * extension)
        for extension in ("png", "svg", "pdf")]
    C.save(paths[1], figure; px_per_unit=2)
    C.save(paths[2], figure)
    C.save(paths[3], figure)
    return paths
end

"""Read the compact shipped organ table, with no private project dependency.

The observed final mass is an annotation recorded in the adjacent shipped TOML;
the CSV contains the two model trajectories, not that independent endpoint.
Archived TOML checks are used only as annotation/regression metadata, never as a
new scientific-validation claim.
"""
function organ_inputs(root=ROOT)
    csv = joinpath(root, "organ", "plotted_values.csv")
    metadata_path = joinpath(root, "organ", "archived_figure_checks.toml")
    data = CSV.read(csv, DataFrame; ntasks=1)
    require_columns(data, (:case, :days_before_harvest, :state, :demand_gCH2O,
        :allocation_gCH2O, :allocation_shortfall, :fruit_mass_kg), csv)
    Set(data.case) == Set(("reference", "catchup")) ||
        throw(ArgumentError("Organ table must contain reference and catchup only"))
    reference = sort(filter(:case => ==("reference"), data), :days_before_harvest)
    catchup = sort(filter(:case => ==("catchup"), data), :days_before_harvest)
    @assert nrow(reference) > 2
    @assert reference.days_before_harvest == catchup.days_before_harvest
    @assert length(unique(reference.days_before_harvest)) == nrow(reference)
    @assert last(reference.days_before_harvest) == 0
    metadata = TOML.parsefile(metadata_path)
    target = metadata["observed_fruit_kg"]
    @assert isfinite(target) && target > 0
    for (table, name) in ((reference, "fixed"), (catchup, "catchup"))
        @assert all(isfinite, table.demand_gCH2O)
        @assert all(isfinite, table.allocation_gCH2O)
        @assert all(table.demand_gCH2O .>= 0)
        @assert all(table.allocation_gCH2O .>= -1e-10)
        @assert all(table.allocation_gCH2O .<= table.demand_gCH2O .+ 1e-6)
        @assert all(isfinite, table.fruit_mass_kg)
        @assert all(diff(table.fruit_mass_kg) .>= -1e-10)
        @assert last(table.state) == "harvested"
        @assert count(table.allocation_shortfall) == metadata[name * "_deficit_days"]
        @assert isapprox(last(table.fruit_mass_kg),
            metadata[name * "_funded_fruit_kg"]; atol=1e-10)
    end
    return (; reference, catchup, target,
        inputs=(csv, metadata_path))
end

"""Draw the two daily-carbon panels and shared fruit-growth panel.

Only the lower green trajectory is hidden when `show_catchup=false`; complete
legends and fixed geometry remain for presentation animation. Every curve comes
directly from the shipped compact CSV. No simulation or calibration is performed.
"""
function render_organ(; root=ROOT, output=DEFAULT_OUTPUT, show_catchup=true)
    input = organ_inputs(root)
    r, n, target = input.reference, input.catchup, input.target
    fig = C.Figure(size=(1280, 560), fontsize=22,
        figure_padding=(18, 20, 8, 8))
    ticks = -180:60:0
    for (column, table, title, hypothesis) in (
        (1, r, "Fixed daily schedule", "Demand = today's scheduled growth"),
        (2, n, "Schedule + catch-up", "Demand = scheduled + unfinished growth"),
    )
        C.Label(fig[1, column], title; fontsize=26, font=:bold)
        C.Label(fig[2, column], hypothesis; fontsize=21, color="#444444")
        axis = C.Axis(fig[3, column]; ylabel="Bunch carbon\n(g CH₂O/day)",
            xticks=ticks, xticklabelsize=18, ylabelsize=21, yticklabelsize=19,
            xgridvisible=true, ygridcolor=(:black, .09), xgridcolor=(:black, .09))
        # Terminal harvest clears stocks and requests; it is not another deficit.
        active = filter(:state => !=("harvested"), table)
        C.band!(axis, active.days_before_harvest,
            active.allocation_gCH2O, active.demand_gCH2O; color=(DEFICIT, .23))
        C.lines!(axis, active.days_before_harvest, active.demand_gCH2O;
            color=OLD, linewidth=2.4, linestyle=:dash)
        C.lines!(axis, active.days_before_harvest, active.allocation_gCH2O;
            color=ALLOCATION, linewidth=2.4)
        C.xlims!(axis, -204, 8)
        C.ylims!(axis, 0, nothing)
    end
    C.Legend(fig[4, 1:2],
        [C.LineElement(color=OLD, linewidth=2.6, linestyle=:dash),
         C.LineElement(color=ALLOCATION, linewidth=2.6),
         C.PolyElement(color=(DEFICIT, .23))],
        ["Demand", "Allocation", "Carbon deficit in each run"];
        orientation=:horizontal, framevisible=false, labelsize=20,
        patchsize=(29, 14), colgap=24, tellheight=true)

    mass = C.Axis(fig[5, 1:2]; ylabel="Fruit dry mass\n(kg DM)",
        xlabel="Days before observed harvest", xticks=ticks, yticks=0:2:10,
        xlabelsize=22, ylabelsize=22, xticklabelsize=20, yticklabelsize=20,
        ygridcolor=(:black, .09), xgridcolor=(:black, .09))
    C.lines!(mass, r.days_before_harvest, r.fruit_mass_kg;
        color=OLD, linewidth=3.5)
    C.lines!(mass, n.days_before_harvest, n.fruit_mass_kg;
        color=NEW, linewidth=3.5, visible=show_catchup)
    C.scatter!(mass, [0], [target]; color=OBSERVED, markersize=11)
    C.vlines!(mass, [0]; color=(:black, .2), linestyle=:dot)
    # Preserve the wording and positions of the archived conference illustration.
    C.text!(mass, -195, 9.65;
        text=C.rich("Demand skyrocket\nThe bunch becomes more ",
            C.rich("competitive"; font=:bold), " rel. to other bunches"),
        fontsize=19, color="#444444", align=(:left, :top))
    C.text!(mass, -3, 8.65; text="Observed $(fmt(target)) kg",
        align=(:right, :bottom), fontsize=21, color=:black)
    C.xlims!(mass, -204, 8)
    C.ylims!(mass, -.15, 10.3)
    C.Legend(fig[6, 1:2],
        [C.LineElement(color=OLD, linewidth=3.3),
         C.LineElement(color=NEW, linewidth=3.3),
         C.MarkerElement(color=OBSERVED, marker=:circle, markersize=10)],
        ["Fixed schedule ($(fmt(last(r.fruit_mass_kg))) kg)",
         "Catch-up ($(fmt(last(n.fruit_mass_kg))) kg)", "Observed final mass"];
        orientation=:horizontal, framevisible=false, labelsize=20,
        patchsize=(29, 14), colgap=24)
    C.Label(fig[7, 1:2],
        "Same PR bunch, target and harvest date. External harvest correction excluded. Top panels use different y scales.";
        fontsize=16, color="#555555")
    C.rowsize!(fig.layout, 3, C.Relative(.31))
    C.rowsize!(fig.layout, 5, C.Relative(.36))
    C.rowgap!(fig.layout, 7)
    C.colgap!(fig.layout, 36)
    stem = show_catchup ? "02_single_bunch_with_catchup" :
        "02_single_bunch_without_catchup"
    paths = save_formats(fig, joinpath(output, "organ"), stem)
    return (; paths, inputs=input.inputs, target,
        fixed_final=last(r.fruit_mass_kg), catchup_final=last(n.fruit_mass_kg),
        fixed_deficit_days=count(r.allocation_shortfall),
        catchup_deficit_days=count(n.allocation_shortfall), show_catchup)
end

"""Draw the annual fruit panel from the shipped annual sums, without reaggregation.

These are the same 50 measured PR cohorts grouped by observed harvest year,
not exhaustive annual palm or plantation yield. Growth excludes external endpoint
correction; observed mass targets and harvest dates were fixed in the experiment.
"""
function render_annual_fruit(; root=ROOT, output=DEFAULT_OUTPUT)
    csv = joinpath(root, "annual_fruit", "plotted_values.csv")
    values = CSV.read(csv, DataFrame; ntasks=1)
    require_columns(values, (:year, :funded_fruit_dry_kg, :observed_fruit_dry_kg,
        :measured_bunches, :treatment), csv)
    @assert Set(values.treatment) == Set(("reference", "catchup"))
    annual = Dict(case => sort(filter(:treatment => ==(case), values), :year)
        for case in ("reference", "catchup"))
    for case in ("reference", "catchup")
        table = annual[case]
        @assert table.year == collect(2014:2022)
        @assert sum(table.measured_bunches) == 50
        @assert all(isfinite, table.funded_fruit_dry_kg)
        @assert all(table.funded_fruit_dry_kg .>= 0)
        @assert all(isfinite, table.observed_fruit_dry_kg)
        @assert all(table.observed_fruit_dry_kg .>= 0)
    end
    @assert annual["reference"].observed_fruit_dry_kg ==
        annual["catchup"].observed_fruit_dry_kg
    @assert annual["reference"].measured_bunches ==
        annual["catchup"].measured_bunches
    fig = C.Figure(size=(600, 470), fontsize=19,
        figure_padding=(24, 18, 10, 8))
    axis = C.Axis(fig[1, 1]; title="Fruit dry mass",
        ylabel="Allocated dry mass (kg/palm/year)", xlabel="Harvest year",
        xticks=2014:2:2022, titlesize=21, xlabelsize=19, ylabelsize=18,
        xticklabelsize=17, yticklabelsize=17)
    for (case, color) in (("reference", OLD), ("catchup", NEW))
        table = annual[case]
        C.scatterlines!(axis, table.year, table.funded_fruit_dry_kg;
            color, linewidth=3.5, markersize=8)
    end
    observed = annual["reference"]
    C.scatter!(axis, observed.year, observed.observed_fruit_dry_kg;
        color=OBSERVED, markersize=11)
    C.ylims!(axis, 0, nothing)
    paths = save_formats(fig, joinpath(output, "annual_fruit"),
        "fruit_dry_mass_red_observations")
    return (; paths, inputs=(csv,), measured_bunches=50,
        observed_total_kg=sum(observed.observed_fruit_dry_kg),
        fixed_total_kg=sum(annual["reference"].funded_fruit_dry_kg),
        catchup_total_kg=sum(annual["catchup"].funded_fruit_dry_kg))
end

"""Render both organ animation frames and the annual panel from public inputs.

Execute through a Kaimon-controlled Julia session with CSV, DataFrames and
CairoMakie available:

```julia
include("path/to/sources/render_public_figures.jl")
XPalmPublicFigureRenderer.render_all()
```

Original archived figures and generator sources are not overwritten. The output
checks record drawing/data checks only. They do not rerun or validate the
underlying scientific model, observation mapping, or calibration.
"""
function render_all(; root=ROOT, output=DEFAULT_OUTPUT)
    source_inputs = [
        joinpath(root, "organ", "plotted_values.csv"),
        joinpath(root, "organ", "archived_figure_checks.toml"),
        joinpath(root, "annual_fruit", "plotted_values.csv"),
        @__FILE__,
    ]
    before = Dict(relpath(path, root) => digest(path) for path in source_inputs)
    without = render_organ(; root, output, show_catchup=false)
    with = render_organ(; root, output, show_catchup=true)
    annual = render_annual_fruit(; root, output)
    @assert all(digest(path) == before[relpath(path, root)] for path in source_inputs)
    paths = vcat(without.paths, with.paths, annual.paths)
    checks = Dict(
        "drawing_checks_passed" => true,
        "input_files_unchanged" => true,
        "simulation_executed" => false,
        "calibration_executed" => false,
        "private_project_required" => false,
        "archived_figures_overwritten" => false,
        "pixel_identical_to_archives_asserted" => false,
        "observation_color" => OBSERVED,
        "organ_observed_target_kg" => with.target,
        "organ_fixed_funded_kg" => with.fixed_final,
        "organ_catchup_funded_kg" => with.catchup_final,
        "organ_fixed_deficit_days" => with.fixed_deficit_days,
        "organ_catchup_deficit_days" => with.catchup_deficit_days,
        "annual_measured_bunches" => annual.measured_bunches,
        "annual_observed_total_kg" => annual.observed_total_kg,
        "annual_fixed_total_kg" => annual.fixed_total_kg,
        "annual_catchup_total_kg" => annual.catchup_total_kg,
        "input_sha256" => before,
        "output_sha256" => Dict(relpath(path, output) => digest(path) for path in paths),
    )
    mkpath(output)
    open(joinpath(output, "DRAWING_CHECKS.toml"), "w") do io
        TOML.print(io, checks)
    end
    return (; output, paths, organ_target_kg=with.target,
        organ_fixed_kg=with.fixed_final, organ_catchup_kg=with.catchup_final,
        annual_observed_kg=annual.observed_total_kg,
        annual_fixed_kg=annual.fixed_total_kg, annual_catchup_kg=annual.catchup_total_kg)
end

end # module
