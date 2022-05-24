using XPalm
using Documenter

DocMeta.setdocmeta!(XPalm, :DocTestSetup, :(using XPalm); recursive=true)

makedocs(;
    modules=[XPalm],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo="https://github.com/PalmStudio/PlantMeteo.jl/blob/{commit}{path}#{line}",
    sitename="PlantMeteo.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://PalmStudio.github.io/PlantMeteo.jl",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
    ]
)

deploydocs(;
    repo="github.com/PalmStudio/XPalm.jl",
    devbranch="main"
)
