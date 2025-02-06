using XPalmModel
using Documenter

DocMeta.setdocmeta!(XPalmModel, :DocTestSetup, :(using XPalmModel); recursive=true)

makedocs(;
    modules=[XPalmModel],
    authors="Rémi Vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("PalmStudio", "XPalmModel.jl"),
    sitename="XPalmModel.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://PalmStudio.github.io/XPalmModel.jl",
        edit_link="main",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
    ]
)

deploydocs(;
    repo="github.com/PalmStudio/XPalmModel.jl",
    devbranch="main"
)
