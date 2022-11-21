using XPalm
using Documenter

DocMeta.setdocmeta!(XPalm, :DocTestSetup, :(using XPalm); recursive=true)

makedocs(;
    modules=[XPalm],
    authors="Rémi Vezy <VEZY@users.noreply.github.com> and contributors",
    repo="https://github.com/PalmStudio/XPalm.jl/blob/{commit}{path}#{line}",
    sitename="XPalm.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://PalmStudio.github.io/XPalm.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/PalmStudio/XPalm.jl",
    devbranch="main",
)
