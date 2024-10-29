module XPalmPluto

import XPalm: notebook
import Pluto


function template_pluto_notebook()
    Pluto.run(notebook="")
end

export template_pluto_notebook
end