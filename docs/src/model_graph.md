# XPalm model graph

The visualization below is generated from XPalm's default `CompositeModel`
during the documentation build. It is read-only, but you can search the graph,
switch between application, object, and execution projections, and select any
node or relationship to inspect its configuration.

```@raw html
<iframe
    src="../www/xpalm_model_mapping.html"
    title="Interactive graph of the default XPalm composite model"
    style="width: 100%; height: 82vh; border: 1px solid #d7d2c8; border-radius: 8px; background: #f8f3eb;"
    loading="lazy"
></iframe>
```

## Inspect the graph from Julia

XPalm assembles the same model with the PlantSimEngine scene/object API:

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
