# XPalm model graph

XPalm assembles its model with the PlantSimEngine scene/object API:

```julia
using XPalm, PlantSimEngine

palm = Palm()
scene = xpalm_scene(palm)
compiled = Advanced.refresh_bindings!(scene)
```

Use PlantSimEngine's structured explanation functions to inspect the compiled
model:

```julia
Diagnostics.explain_applications(compiled)
Diagnostics.explain_bindings(compiled)
Diagnostics.explain_calls(compiled)
Diagnostics.explain_schedule(compiled)
Diagnostics.explain_writers(compiled)
```

These tables are the authoritative representation of XPalm's application
targets, cross-object inputs, hard calls, rates, and variable writers.
