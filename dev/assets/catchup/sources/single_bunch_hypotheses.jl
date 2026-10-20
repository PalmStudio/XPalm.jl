module SingleBunchHypotheses

using CSV, DataFrames, Dates, Printf, SHA, TOML
import CairoMakie as C

const INPUT = joinpath(@__DIR__, "figures", "individual_bunch_trajectories.csv")
const OUTPUT = joinpath(@__DIR__, "single_bunch")
const OLD = "#777777"
const NEW = "#009E73"
const ALLOCATION = "#496B86"
const DEFICIT = "#D55E00"
const OBSERVED = "#D62728"
fmt(x) = @sprintf("%.2f", x)
digest(path) = open(io -> bytes2hex(sha256(io)), path)

"""Render the same observed bunch under the two saved, coupled hypotheses.

Each upper panel uses demand, allocation and deficit from its own run.
The lower panel uses cumulative carbon-funded fruit growth, before the
external harvest correction. This script changes no simulation or parameter.
"""
function render(; show_catchup=true, stem="02_single_bunch_hypotheses")
    mkpath(OUTPUT)
    all_data = CSV.read(INPUT, DataFrame; types=Dict(:date=>Date))
    data = filter(:field_phytomer => ==(146), all_data)
    sort!(data, [:case, :date])
    r = filter(:case => ==("reference"), data)
    n = filter(:case => ==("catchup"), data)
    @assert r.date == n.date
    @assert length(unique(r.uid)) == length(unique(n.uid)) == 1
    @assert only(unique(r.uid)) == only(unique(n.uid))
    @assert last(r.date) == Date(2018,11,5)
    @assert all(r.allocation_gCH2O .<= r.demand_gCH2O .+ 1e-6)
    @assert all(n.allocation_gCH2O .<= n.demand_gCH2O .+ 1e-6)
    @assert count(r.allocation_shortfall) == 65
    @assert count(n.allocation_shortfall) == 68
    @assert isapprox(last(r.fruit_mass_kg), 6.406178997515965; atol=1e-10)
    @assert isapprox(last(n.fruit_mass_kg), 8.549540315535237; atol=1e-10)
    target = 8.559230536378074
    @assert all(diff(r.fruit_mass_kg) .>= -1e-10)
    @assert all(diff(n.fruit_mass_kg) .>= -1e-10)
    # Native harvest clears organ stocks. The saved funded trajectory retains
    # growth accumulated before that event and excludes the external addition.
    @assert last(r.state) == last(n.state) == "harvested"
    @assert iszero(last(r.current_fruit_biomass_gDM))
    @assert iszero(last(n.current_fruit_biomass_gDM))

    fig = C.Figure(size=(1280,560), fontsize=22, figure_padding=(18,20,8,8))
    tops = Any[]
    ticks = -180:60:0
    for (column, d, title, hypothesis) in (
        (1,r,"Fixed daily schedule","Demand = today's scheduled growth"),
        (2,n,"Schedule + catch-up","Demand = scheduled + unfinished growth"))
        C.Label(fig[1,column], title; fontsize=26, font=:bold)
        C.Label(fig[2,column], hypothesis; fontsize=21, color="#444444")
        ax = C.Axis(fig[3,column]; ylabel="Bunch carbon\n(g CH₂O/day)",
            xticks=ticks, xticklabelsize=18,
            ylabelsize=21, yticklabelsize=19, xgridvisible=true,
            ygridcolor=(:black,.09), xgridcolor=(:black,.09))
        push!(tops, ax)
        # Demand drops to zero at terminal harvest; omit that state transition
        # from daily curves to avoid displaying it as a new carbon deficit.
        active = filter(:state => !=("harvested"), d)
        x = active.days_before_harvest
        C.band!(ax,x,active.allocation_gCH2O,active.demand_gCH2O;
            color=(DEFICIT,.23))
        C.lines!(ax,x,active.demand_gCH2O; color=OLD, linewidth=2.4, linestyle=:dash)
        C.lines!(ax,x,active.allocation_gCH2O; color=ALLOCATION, linewidth=2.4)
        C.xlims!(ax,-204,8)
        C.ylims!(ax,0,nothing)
    end
    # Explicit, independent upper y scales keep both daily series readable.
    # The shared lower scale and identical x axes support trajectory comparison.
    C.Legend(fig[4,1:2],
        [C.LineElement(color=OLD,linewidth=2.6,linestyle=:dash),
         C.LineElement(color=ALLOCATION,linewidth=2.6),
         C.PolyElement(color=(DEFICIT,.23))],
        ["Demand", "Allocation", "Carbon deficit in each run"];
        orientation=:horizontal, framevisible=false, labelsize=20,
        patchsize=(29,14), colgap=24, tellheight=true)

    mass = C.Axis(fig[5,1:2]; ylabel="Fruit dry mass\n(kg DM)",
        xlabel="Days before observed harvest", xticks=ticks, yticks=0:2:10,
        xlabelsize=22, ylabelsize=22, xticklabelsize=20, yticklabelsize=20,
        ygridcolor=(:black,.09), xgridcolor=(:black,.09))
    C.lines!(mass,r.days_before_harvest,r.fruit_mass_kg; color=OLD,linewidth=3.5)
    # Both animation frames retain the same data, limits and full legend.
    # Visibility changes only this lower-panel curve; all layout stays fixed.
    C.lines!(mass,n.days_before_harvest,n.fruit_mass_kg;
        color=NEW,linewidth=3.5,visible=show_catchup)
    C.scatter!(mass,[0],[target]; color=OBSERVED,markersize=11)
    C.vlines!(mass,[0]; color=(:black,.2),linestyle=:dot)
    C.text!(mass,-195,9.65;
        text=C.rich("Demand skyrocket\nThe bunch becomes more ",
            C.rich("competitive"; font=:bold), " rel. to other bunches"),
        fontsize=19, color="#444444", align=(:left,:top))
    C.text!(mass,-3,8.65; text="Observed $(fmt(target)) kg",
        align=(:right,:bottom), fontsize=21, color=:black)
    C.xlims!(mass,-204,8)
    C.ylims!(mass,-.15,10.3)
    C.Legend(fig[6,1:2],
        [C.LineElement(color=OLD,linewidth=3.3), C.LineElement(color=NEW,linewidth=3.3),
         C.MarkerElement(color=OBSERVED,marker=:circle,markersize=10)],
        ["Fixed schedule ($(fmt(last(r.fruit_mass_kg))) kg)",
         "Catch-up ($(fmt(last(n.fruit_mass_kg))) kg)", "Observed final mass"];
        orientation=:horizontal, framevisible=false,labelsize=20,
        patchsize=(29,14),colgap=24)
    C.Label(fig[7,1:2],
        "Same PR bunch, target and harvest date. External harvest correction excluded. Top panels use different y scales.";
        fontsize=16, color="#555555")
    C.rowsize!(fig.layout,3,C.Relative(.31))
    C.rowsize!(fig.layout,5,C.Relative(.36))
    C.rowgap!(fig.layout,7)
    C.colgap!(fig.layout,36)
    paths=String[]
    for ext in ("png","pdf","svg")
        output=joinpath(OUTPUT,stem*"."*ext)
        C.save(output,fig; px_per_unit=2)
        push!(paths,output)
    end
    CSV.write(joinpath(OUTPUT,"plotted_daily_values.csv"),data)
    checks=Dict(
        "field_phytomer"=>146, "harvest_date"=>"2018-11-05",
        "input_sha256"=>digest(INPUT), "source_sha256"=>digest(@__FILE__),
        "observed_fruit_kg"=>target,
        "fixed_funded_fruit_kg"=>last(r.fruit_mass_kg),
        "catchup_funded_fruit_kg"=>last(n.fruit_mass_kg),
        "fixed_deficit_days"=>count(r.allocation_shortfall),
        "catchup_deficit_days"=>count(n.allocation_shortfall),
        "fixed_max_demand_gCH2O_day"=>maximum(r.demand_gCH2O),
        "catchup_max_demand_gCH2O_day"=>maximum(n.demand_gCH2O),
        "own_run_deficits"=>true, "external_harvest_correction_excluded"=>true,
        "new_simulation"=>false,
        "lower_catchup_curve_visible"=>show_catchup,
        "observation_color"=>OBSERVED,
        "complete_legend_retained"=>true,
        "outputs"=>Dict(basename(p)=>digest(p) for p in paths))
    checks_name = stem == "02_single_bunch_hypotheses" ? "FIGURE_CHECKS.toml" : stem*"_CHECKS.toml"
    open(joinpath(OUTPUT,checks_name),"w") do io
        TOML.print(io,checks)
    end
    (;paths, fixed_peak=maximum(r.demand_gCH2O), catchup_peak=maximum(n.demand_gCH2O),
        fixed_final=last(r.fruit_mass_kg),catchup_final=last(n.fruit_mass_kg))
end

"""Export two aligned animation frames with red observations and full legends."""
function render_animation_frames()
    without = render(;show_catchup=false,stem="02_single_bunch_without_catchup")
    with = render(;show_catchup=true,stem="02_single_bunch_with_catchup")
    (;without,with)
end

end
