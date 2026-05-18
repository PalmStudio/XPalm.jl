using XPalm
using Documenter
using PlantSimEngine

DocMeta.setdocmeta!(XPalm, :DocTestSetup, :(using XPalm); recursive=true)


function build_model_graph_asset()
    isdefined(PlantSimEngine, :write_graph_view) ||
        error("PlantSimEngine.write_graph_view is required to build the XPalm model graph page. Dev or update the docs PlantSimEngine dependency.")

    # assets_dir = joinpath(@__DIR__, "build", "assets")
    assets_dir = joinpath(@__DIR__, "src", "www")

    mkpath(assets_dir)

    palm = XPalm.Palm()
    mapping = XPalm.model_mapping(palm)
    PlantSimEngine.write_graph_view(joinpath(assets_dir, "xpalm_model_mapping.html"), mapping)

    return nothing
end

build_model_graph_asset()

makedocs(;
    modules=[XPalm, XPalm.VPalm],
    authors="Rémi Vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("PalmStudio", "XPalm.jl"),
    sitename="XPalm.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://PalmStudio.github.io/XPalm.jl",
        edit_link="main",
        assets=String[],
        size_threshold=3_500_000,
    ),
    pages=[
        "Home" => "index.md",
        "XPalm" => [
            "XPalm notebook" => "notebook.md",
            "Running XPalm" => "running.md",
            "Model graph" => "model_graph.md",
        ],
        "Vpalm" => [
            "Parameters" => "vpalm/parameters.md",
            "Reconstruction" => "vpalm/reconstruction.md",
        ],
        "Coupling" => "coupling.md",
        "API" => [
            "Index" => "api_index.md",
            "XPalm API" => "api.md",
            "XPalm.VPalm API" => "vpalm/api.md",
        ],
    ],
)

deploydocs(;
    repo="github.com/PalmStudio/XPalm.jl",
    devbranch="main"
)
