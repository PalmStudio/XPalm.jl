"""
    notebook()

Open XPalm in a template Pluto notebook.

# Example

```julia
using XPalm, Pluto
XPalm.notebook()
```
"""
function notebook()
    ext = Base.get_extension(@__MODULE__, :XPamlPluto)
    if !isnothing(ext)
        return ext.template_pluto_notebook()
    else
        error("Please install and load Pluto to use this function: `] add Pluto; using Pluto`")
    end
end