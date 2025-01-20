### A Pluto.jl notebook ###
# v0.20.3

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ f8a57cfe-960e-11ef-3974-3d60ebc34f7b
begin
    import Pkg
    # activate a temporary environment
    Pkg.activate(mktempdir())
    Pkg.add([
        Pkg.PackageSpec(url="https://github.com/PalmStudio/XPalm.jl", rev="main"),
        Pkg.PackageSpec(name="CairoMakie"),
        Pkg.PackageSpec(name="AlgebraOfGraphics"),
        Pkg.PackageSpec(name="PlantMeteo"),
        Pkg.PackageSpec(name="DataFrames"),
        Pkg.PackageSpec(name="CSV"),
        Pkg.PackageSpec(name="Statistics"),
        Pkg.PackageSpec(name="Dates"),
        Pkg.PackageSpec(name="YAML"),
        Pkg.PackageSpec(name="PlutoHooks"),
        Pkg.PackageSpec(name="PlutoLinks"),
        Pkg.PackageSpec(name="PlutoUI"),
        Pkg.PackageSpec(name="HypertextLiteral"),
    ])
end

# ╔═╡ 5dfdc85c-5f5a-48fc-a308-d205f862fb27
begin
    using PlantMeteo, DataFrames, CSV, Statistics, Dates, XPalm, YAML
    using PlutoHooks, PlutoLinks, PlutoUI
    using HypertextLiteral
    using CairoMakie, AlgebraOfGraphics
end

# ╔═╡ 77aae20b-6310-4e34-8599-e08d01b28c9f
md"""
## Install

Installing packages
"""

# ╔═╡ 7fc8085f-fb74-4171-8df1-527ee1edfa73
md"""
## Import data

- Meteorology
"""

# ╔═╡ 1fa0b119-26fe-4807-8aea-50cdbd591656
meteo = let
    m = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo"), DataFrame)
    m.duration = [Dates.Day(i[1:1]) for i in m.duration]
    Weather(m)
    m
end

# ╔═╡ 7165746e-cc57-4392-bb6b-705cb7221c24
md"""
- Model parameters
"""

# ╔═╡ 73f8cf85-cb03-444e-bf9e-c65363e9ffb8
params = let
    file = joinpath("0-data/xpalm_parameters.yml")
    update_time_ = PlutoLinks.@use_file_change(file)
    @use_memo([update_time_]) do
        YAML.load_file(file, dicttype=Dict{Symbol,Any})
    end
end

# ╔═╡ 9ec6a0fc-cbe2-4710-a366-6d78173d0379
md"""
- Model run:
"""

# ╔═╡ d6b7618a-c48e-404a-802f-b13c98257308
md"""
## Plotting all variables
"""

# ╔═╡ 387ee199-3f98-4c4a-9399-4bafe5f5243e
md"""
## Plotting one variable
"""

# ╔═╡ 460efc79-762c-4e97-b2dd-06afe83dfe8e
md"""
Choose one variable per scale:
"""

# ╔═╡ 5997198e-c8c4-494c-b904-bf54ae69e7e5
md"""
# References
"""

# ╔═╡ 1dbed83e-ec41-4daf-b398-4089e66b9842
function multiscale_variables_display(vars, Child, input_function, default)
    var_body = []
    for (key, values) in vars
        variable_names = sort(collect(values), by=x -> string(x) |> lowercase)
        length(variable_names) == 0 && continue
        Dict("Soil" => (:ftsw,), "Scene" => (:lai,), "Plant" => (:leaf_area, :Rm, :aPPFD, :biomass_bunch_harvested_organs), "Leaf" => (:leaf_area,))
        default_at_scale = [get(default, key, ())...]

        push!(var_body,
            @htl("""
            <div style="display: inline-flex; flex-direction: column; padding: 5px 10px; margin: 5px; border: 1px solid #ddd; border-radius: 5px; box-shadow: 1px 1px 3px rgba(0, 0, 0, 0.1);">
                     <h3 style="margin: 0 0 5px 0; font-size: 1em;">$key</h3>
            	$(Child(key, input_function(variable_names, default_at_scale)))
            </div>
            """)
        )
    end

    return var_body
end

# ╔═╡ 96737f48-5478-4fbc-b72b-1ca33efa4846
function variables_display(vars; input_function=(x, default) -> PlutoUI.MultiCheckBox(x, orientation=:row, default=default), default=Dict())
    PlutoUI.combine() do Child
        @htl("""
        <div>
        	<div style="display: flex; flex-wrap: wrap; gap: 0px;">
        	    $(multiscale_variables_display(vars, Child, input_function, default))
        	</div>
        </div>
        """)
    end
end

# ╔═╡ bde1793e-983a-47e4-94a6-fbbe53fe72d6
@bind variables variables_display(
    Dict(k => keys(merge(v...)) for (k, v) in XPalm.PlantSimEngine.variables(XPalm.model_mapping(XPalm.Palm()))),
    default=Dict("Soil" => (:ftsw,), "Scene" => (:lai,), "Plant" => (:leaf_area, :Rm, :aPPFD, :biomass_bunch_harvested), "Leaf" => (:leaf_area,))
)

# ╔═╡ 9bdd9351-c883-492f-adcc-062537fb9ecc
variables_dict = filter(x -> length(last(x)) > 0, Dict{String,Any}(zip(string.(keys(variables)), [(i...,) for i in values(variables)])))

# ╔═╡ 8bc0ac37-e34e-469b-9346-0231aa28be63
df = let
    p = XPalm.Palm(parameters=params)
    if length(variables_dict) > 0
        sim = xpalm(meteo, DataFrame; palm=p, vars=variables_dict)
    end
end

# ╔═╡ a8c2f2f2-e016-494d-9f7b-c445c62b0810
dfs = Dict(i => select(filter(row -> row.organ == i, df), [:timestep, :node, variables_dict[i]...]) for i in keys(variables_dict));

# ╔═╡ f6ad8a2a-75ec-4f9b-a462-fccccf7f58e5
let
    htmlplots = []
    for (scale, df) in dfs
        n_nodes_scale = length(unique(dfs[scale].node))

        if n_nodes_scale == 1
            m = mapping(:timestep, :value, layout=:variable)
        else
            m = mapping(:timestep, :value, color=:node => nonnumeric, layout=:variable)
        end

        height_plot = max(300, 300 * length(variables_dict[scale]) / 2)

        plt = data(stack(dfs[scale], Not([:timestep, :node]), view=true)) * m * visual(Lines)

        pag = paginate(plt, layout=2)

        # info = htl"$scale"
        # p = draw(plt; figure=(;size=(800,height_plot)), facet=(;linkyaxes=:none))
        figuregrids = draw(pag; figure=(; size=(800, 300)), facet=(; linkxaxes=:none, linkyaxes=:none), legend=(; show=false))
        push!(htmlplots, htl"<h4>$scale:</h4>")
        for i in figuregrids
            push!(htmlplots, htl"<div>$i</div>")
        end
    end

    htl"<h5>Plots:</h5>$htmlplots"
end

# ╔═╡ d1377c41-98a8-491d-a4e5-d427e3cb7090
@bind variables_one variables_display(variables_dict; input_function=(x, default) -> Select(x, default=default))

# ╔═╡ 279a3e36-00c6-4506-a0a7-71e876aef781
@bind nodes variables_display(Dict(scale => unique(dfs[scale].node) for (scale, df) in dfs); input_function=(x, default) -> MultiSelect(x))

# ╔═╡ 462fc904-a5bc-4fc0-b342-166d2b02376c
let
    variables_one_dict = Dict(zip(string.(keys(variables_one)), values(variables_one)))
    nodes_dict = Dict(zip(string.(keys(nodes)), values(nodes)))
    htmlplots = []
    for (scale, df) in dfs
        n_nodes_scale = length(unique(dfs[scale].node))

        if n_nodes_scale == 1
            m = mapping(:timestep, variables_one_dict[scale])
            df_plot = select(dfs[scale], [:timestep, :node, variables_one_dict[scale]])
        else
            m = mapping(:timestep, variables_one_dict[scale], color=:node => nonnumeric)
            df_plot = select(df, [:timestep, :node, variables_one_dict[scale]])
            filter!(row -> row.node in nodes_dict[scale], df_plot)
        end

        height_plot = 300

        plt = data(df_plot) * m * visual(Lines)
        p = draw(plt; figure=(; size=(800, height_plot)))
        push!(htmlplots, htl"<h4>$scale:</h4>")
        push!(htmlplots, htl"<div>$p</div>")
    end

    htl"<h5>Plots:</h5>$htmlplots"
end

# ╔═╡ Cell order:
# ╟─77aae20b-6310-4e34-8599-e08d01b28c9f
# ╟─f8a57cfe-960e-11ef-3974-3d60ebc34f7b
# ╠═5dfdc85c-5f5a-48fc-a308-d205f862fb27
# ╟─7fc8085f-fb74-4171-8df1-527ee1edfa73
# ╟─1fa0b119-26fe-4807-8aea-50cdbd591656
# ╟─7165746e-cc57-4392-bb6b-705cb7221c24
# ╠═73f8cf85-cb03-444e-bf9e-c65363e9ffb8
# ╟─9ec6a0fc-cbe2-4710-a366-6d78173d0379
# ╟─8bc0ac37-e34e-469b-9346-0231aa28be63
# ╟─bde1793e-983a-47e4-94a6-fbbe53fe72d6
# ╟─9bdd9351-c883-492f-adcc-062537fb9ecc
# ╟─a8c2f2f2-e016-494d-9f7b-c445c62b0810
# ╟─d6b7618a-c48e-404a-802f-b13c98257308
# ╟─f6ad8a2a-75ec-4f9b-a462-fccccf7f58e5
# ╟─387ee199-3f98-4c4a-9399-4bafe5f5243e
# ╟─460efc79-762c-4e97-b2dd-06afe83dfe8e
# ╟─d1377c41-98a8-491d-a4e5-d427e3cb7090
# ╠═279a3e36-00c6-4506-a0a7-71e876aef781
# ╟─462fc904-a5bc-4fc0-b342-166d2b02376c
# ╟─5997198e-c8c4-494c-b904-bf54ae69e7e5
# ╟─96737f48-5478-4fbc-b72b-1ca33efa4846
# ╟─1dbed83e-ec41-4daf-b398-4089e66b9842
