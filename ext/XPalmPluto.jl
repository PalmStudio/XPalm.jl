module XPalmPluto

import XPalm: notebook
import Pluto


function template_pluto_notebook()
    Pluto.run(notebook=joinpath(@__DIR__, "template_notebook.jl"))
end

export template_pluto_notebook
end