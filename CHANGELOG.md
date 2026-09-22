# Changelog

## 0.7.0

XPalm 0.7.0 moves simulations to PlantSimEngine 0.15, improves dynamic palm
reconstruction with VPalm, and corrects carbon and biomass accounting. The
scientific corrections intentionally change some growth and yield predictions
relative to v0.6.1. Review existing calibrations and comparisons with saved
simulation results when upgrading.

### Carbon, biomass, and model results

- Use grams of CH₂O-equivalent consistently for assimilate production, carbon
  demand, allocation, respiration, and reserves. Structural organ biomass is
  expressed separately in grams of dry matter (gDM), with construction costs
  applied when converting allocated assimilate into growth.
- Correct initial whole-leaf mass, internode growth demand, and maximum
  male-inflorescence dry mass. Track structural leaf mass separately for
  leaflets, rachis, and petiole.
- Update maintenance-respiration parameters and living-biomass fractions, and
  correct respiration initialization for newly created organs and the reset of
  reserve-mobilization respiration between timesteps.
- Declare the units and spatial and temporal meaning of carbon and light
  variables. Incompatible model connections are detected during model
  compilation. Custom photosynthesis models that return a CO₂ flux need an
  explicit conversion to daily plant totals in g CH₂O-equivalent, with
  consistent treatment of respiration; see the
  [coupling guidance](docs/src/running.md#assimilate-currency-and-photosynthesis-coupling).
- Add a versioned numerical reference for the full 4,160-day example, covering
  growth, leaf area index, harvest events, and bunch and oil yield. The
  [comparison with v0.6.1](test/references/regression/v0.7.0-dev/README.md)
  documents the intentional changes. The v0.6.1 reference remains unchanged.

### Dynamic architecture with VPalm

- Improve reconstruction of growing leaves: leaflet layout uses the final
  rachis length as its reference, while expansion and unfolding follow the
  developing leaf. Correct leaflet placement, mature-leaf updates, stem
  dimensions, and removal of geometry after pruning.
- Use simulated structural biomass and non-structural reserves to calculate
  fresh masses for VPalm. Rachis and leaflet loads therefore respond to the
  mass simulated by XPalm.
- Add juvenile leaflet and rachis relationships informed by JPCE measurements
  to the default dynamic parameter set. The juvenile petiole-base settings
  remain provisional; their scope is described in the
  [parameter documentation](docs/src/vpalm/parameters.md).
- Reduce repeated geometry work by updating leaves at developmental events and
  reusing biomechanics buffers. Preserve geometry placement when meshes are
  merged at different scales.
- Fix first-use architecture calls from compiled Julia functions by initializing
  VPalm when XPalm loads. `XPalm.load_vpalm!()` returns the initialized module;
  importing XPalm does not open a renderer.

The coupling remains one-way: XPalm growth drives VPalm geometry. Reconstructed
mesh area does not feed back into XPalm's light interception or growth.

### Upgrading from v0.6.1

- **Dependencies:** require PlantSimEngine 0.15, PlantGeom 0.20, and
  MultiScaleTreeGraph 0.16. Julia 1.10 remains supported. Add compatibility with
  PlantMeteo 0.9, OrderedCollections 2, and Pluto 1.0. Package, test, and
  documentation environments use registered dependencies.
- **Simulation results:** `xpalm(meteo)` now returns a
  `PlantSimEngine.Simulation`. The `xpalm(meteo, DataFrame; vars=...)` form still
  returns a dictionary of tables by scale. Use `collect_outputs` to retrieve
  selected variables from a simulation. The output `node` column now contains
  the stable simulation object identifier; review code that joins outputs to
  MTG nodes. See [Running XPalm](docs/src/running.md).
- **Custom model assemblies:** replace `XPalm.model_mapping` with
  `model_applications(palm)` and use `xpalm_scene(palm; environment=meteo)` to
  construct a `CompositeModel`. Model kernels use
  `run!(model, status, environment, constants, context)`. Access simulation
  status through PlantSimEngine and remove legacy `plantsimengine_status`
  attributes before importing saved MTGs. Carbon allocation and reserve filling
  publish organ outputs by object identifier, preserving their destinations as
  organs appear.
- **Hard dependencies:** FTSW, FTSW_BP, and phytomer models that call other models
  must run in a compiled `CompositeModel`, using
  `run_call!(context, process_name)`. The package-local compatibility helper and
  direct-kernel fallback have been removed.
- **Geometry model:** replace `LeafGeometryModel` with `GeometryModel` in custom
  assemblies.
- **Parameter files:** update custom files using the
  [YAML](examples/xpalm_parameters.yml) or [JSON](examples/xpalm_parameters.json)
  template. Leaf biomass now requires `leaflets_biomass_contribution`,
  `rachis_biomass_contribution`, and `petiole_biomass_contribution`, which must
  be nonnegative and sum to one; the defaults are 0.30, 0.30, and 0.40. Review
  the revised maintenance-respiration settings and male-organ maximum biomass. The former
  internode `carbon_concentration` parameter is no longer used to convert
  structural dry mass.

### Validation and documentation

- Add tests for carbon and radiation contracts, changing organ populations,
  geometry lifecycle and mesh placement, and public architecture entry points
  called in fresh Julia processes.
- Add a manual full-cycle numerical and VPalm benchmark workflow. It compares
  simulations with and without architecture after full warm-up, verifies
  physiological-output and structural-biomass agreement, and records timings
  with the resolved dependency environment.
- Update the simulation guide and notebook template for the PlantSimEngine 0.15
  API, and add an interactive graph for inspecting model applications, objects,
  and execution order.
