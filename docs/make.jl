using XPalm
using Documenter

DocMeta.setdocmeta!(XPalm, :DocTestSetup, :(using XPalm); recursive=true)

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
