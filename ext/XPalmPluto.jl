module XPalmPluto

import XPalm: notebook
import Pluto


function template_pluto_notebook(copyto)
    cp(joinpath(@__DIR__, "template_notebook.jl"), copyto)
    @info "Template Pluto notebook created at $copyto"
    Pluto.run(notebook=copyto)
end

export template_pluto_notebook
end