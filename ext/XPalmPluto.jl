module XPalmPluto

import XPalm: notebook
import Pluto


function template_pluto_notebook(copyto; force=false)
    cp(joinpath(@__DIR__, "template_notebook.jl"), copyto; force=force)
    @info "Template Pluto notebook created at $copyto"
    Pluto.run(notebook=copyto)
end

export template_pluto_notebook
end