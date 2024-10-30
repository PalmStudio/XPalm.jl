"""
    notebook(; copyto::String, force::Bool)

Create a new XPalm notebook from a template in `copyto`, and run the notebook.

# Arguments

- `copyto::String=joinpath(pwd(), "xpalm_notebook.jl")`: The path to the new notebook file.
- `force::Bool=false`: If `true`, overwrite the file at `copyto`.

# Example

```julia
using XPalm, Pluto
XPalm.notebook()
```
"""
function notebook(; copyto=joinpath(pwd(), "xpalm_notebook.jl"), force=false)
    ext = Base.get_extension(@__MODULE__, :XPalmPluto)
    if !isnothing(ext)
        isfile(copyto) && !force && error("File already exists at $copyto. Use `force=true` to overwrite it, or change its name.")
        return ext.template_pluto_notebook(copyto; force=force)
    else
        error("Please install and load Pluto to use this function: `] add Pluto; using Pluto`")
    end
end