### A Pluto.jl notebook ###
# v0.20.0

using Markdown
using InteractiveUtils

# ╔═╡ f8a57cfe-960e-11ef-3974-3d60ebc34f7b
begin
    import Pkg
    # activate a temporary environment
    Pkg.activate(mktempdir())
    Pkg.add([
        Pkg.PackageSpec(url="https://github.com/PalmStudio/XPalm.jl", rev="main"),
		Pkg.PackageSpec(name="CairoMakie"),
		Pkg.PackageSpec(name="PlantMeteo"),
		Pkg.PackageSpec(name="DataFrames"),
		Pkg.PackageSpec(name="CSV"),
		Pkg.PackageSpec(name="Statistics"),
		Pkg.PackageSpec(name="Dates"),
		Pkg.PackageSpec(name="YAML"),
		Pkg.PackageSpec(name="PlutoHooks"),
		Pkg.PackageSpec(name="PlutoLinks"),
    ])
	using PlantMeteo, CairoMakie, DataFrames, CSV, Statistics, Dates, XPalm, YAML
	using PlutoHooks, PlutoLinks
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
	m = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/Meteo_Nigeria_PR.txt"), DataFrame)
	Weather(m)
end

# ╔═╡ 7165746e-cc57-4392-bb6b-705cb7221c24
md"""
- Model parameters
"""

# ╔═╡ 5333c864-eb66-4575-a495-ed35f0fe9566
out_vars = Dict{String,Any}(
    "Scene" => (:lai,),
    # "Scene" => (:lai, :scene_leaf_area, :aPPFD, :TEff),
    # "Plant" => (:plant_age, :ftsw, :newPhytomerEmergence, :aPPFD, :plant_leaf_area, :carbon_assimilation, :carbon_offer_after_rm, :Rm, :TT_since_init, :TEff, :phytomer_count, :newPhytomerEmergence),
    # "Leaf" => (:Rm, :potential_area, :TT_since_init, :TEff, :A, :carbon_demand, :carbon_allocation,),
    # "Leaf" => (:Rm, :potential_area),
    # "Internode" => (:Rm, :carbon_allocation, :carbon_demand),
    # "Male" => (:Rm,),
    # "Female" => (:biomass,),
    # "Soil" => (:TEff, :ftsw, :root_depth),
)

# ╔═╡ 73f8cf85-cb03-444e-bf9e-c65363e9ffb8
params = let
	file = joinpath(dirname(dirname(pathof(XPalm))), "examples/xpalm_parameters.yml")
    update_time_ = PlutoLinks.@use_file_change(file)
    @use_memo([update_time_]) do
        YAML.load_file(file, dicttype=Dict{Symbol,Any})
    end
end

# ╔═╡ 8bc0ac37-e34e-469b-9346-0231aa28be63
df = let
	p = XPalm.Palm(parameters=params)
	sim = xpalm(meteo; palm=p, vars=out_vars, sink=DataFrame)
end

# ╔═╡ d6b7618a-c48e-404a-802f-b13c98257308
md"""
## Plotting
"""

# ╔═╡ 6d44748e-74a8-4898-ba6b-9b1b1ef650cc
let 
	f = Figure()
	ax = Axis(f[1, 1],
    	title = "Scene LAI",
    	xlabel = "Time (days)",
    	ylabel = "LAI (m² m⁻²)",
	)
	lines!(ax, df.timestep, df.lai, color = :green)
	f
end

# ╔═╡ Cell order:
# ╟─77aae20b-6310-4e34-8599-e08d01b28c9f
# ╟─f8a57cfe-960e-11ef-3974-3d60ebc34f7b
# ╟─7fc8085f-fb74-4171-8df1-527ee1edfa73
# ╠═1fa0b119-26fe-4807-8aea-50cdbd591656
# ╟─7165746e-cc57-4392-bb6b-705cb7221c24
# ╠═5333c864-eb66-4575-a495-ed35f0fe9566
# ╠═73f8cf85-cb03-444e-bf9e-c65363e9ffb8
# ╠═8bc0ac37-e34e-469b-9346-0231aa28be63
# ╟─d6b7618a-c48e-404a-802f-b13c98257308
# ╠═6d44748e-74a8-4898-ba6b-9b1b1ef650cc
