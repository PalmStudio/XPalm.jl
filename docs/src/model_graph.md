# XPalm model graph

XPalm assembles its model with the PlantSimEngine scene/object API:

```julia
using XPalm, PlantSimEngine

palm = Palm()
scene = xpalm_scene(palm)
compiled = refresh_bindings!(scene)
```

Use PlantSimEngine's structured explanation functions to inspect the compiled
model:

```julia
explain_scene_applications(compiled)
explain_bindings(compiled)
explain_calls(compiled)
explain_schedule(compiled)
explain_writers(compiled)
```

These tables are the authoritative representation of XPalm's application
targets, cross-object inputs, hard calls, rates, and variable writers.
