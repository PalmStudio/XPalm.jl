# Running XPalm using a notebook

The easiest way to run the model is to use the template notebook provided by the package. To run the notebook, you need to install the Pluto package first by running `] add Pluto`. Then, you can run the notebook using the following commands in the Julia REPL:

```julia
using Pluto, XPalm
XPalm.notebook("xpalm_notebook.jl")
```

This command will create a new Pluto notebook (named "xpalm_notebook.jl") in the current directory, and open it automatically for you.

Once closed, you can re-open this notebook by running the same command again. If the file already exists, it will be opened automatically.
