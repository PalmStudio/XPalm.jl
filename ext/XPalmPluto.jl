module XPalmPluto

import XPalm: notebook
import Pluto


function template_pluto_notebook(copyto; force=false)
    if isfile(copyto) && !force
        @info "Notebook already exists at $copyto, opening. Use `force=true` to overwrite it instead."
    else
        cp(joinpath(@__DIR__, "template_notebook.jl"), copyto; force=force)
        chmod(copyto, 0o777)
        @info "New XPalm notebook created at $copyto"
    end

    Pluto.run(notebook=copyto)
end

export template_pluto_notebook
end