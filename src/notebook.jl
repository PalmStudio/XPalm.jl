"""
    notebook(copyto::String; force::Bool)

Open an XPalm notebook or create one from a template at `path`, and run the notebook.

# Arguments

- `path::String`: The path to the notebook file. If it exists, it will be opened (unless `force=true`), otherwise it will be created.
- `force::Bool=false`: If `true`, overwrite the file at `path`.

# Example

```julia
using XPalmModel, Pluto
XPalmModel.notebook()
```
"""
function notebook(path=joinpath(pwd(), "xpalm_notebook.jl"), force=false)
    ext = Base.get_extension(@__MODULE__, :XPalmPluto)
    if !isnothing(ext)
        return ext.template_pluto_notebook(path; force=force)
    else
        error("Please install and load Pluto to use this function: `] add Pluto; using Pluto`")
    end
end