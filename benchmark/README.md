# VPalm geometry performance benchmark

`vpalm_geometry_performance.jl` provides the durable A/B runner used by the
geometry-performance work. It compares `architecture=false` and
`architecture=true` in the same Julia session with a fixed VPalm seed.

Including the runner does not load VPalm. The VPalm module is loaded lazily by
the first `architecture=true` variant. This matters when the architecture-off
path is benchmarked against another XPalm revision: in each fresh session,
warm and measure `_run_benchmark_variant(false, ...)` before running any
architecture-on variant, so VPalm compilation and method-table state cannot
confound the comparison.

The runner separates:

- palm/scene construction;
- simulation;
- biomass checkpoint validation in an independent second simulation;
- retained-output materialization;
- PlantSimEngine object and MTG geometry-node counts;
- structural organ biomass at every 128-day lifecycle checkpoint.

It retains the 21 canonical daily physiological series and compares total leaf,
leaflet, rachis, petiole, internode, male and female biomass (including stalk,
fruit, oil and non-oil compartments) at every lifecycle checkpoint. It writes
five CSV files to the requested directory and fails if any daily output or
biomass total differs exactly between the two variants. On a daily-output
failure it also writes `daily_difference.csv`, including the two trajectories
and their difference; a later successful reuse of the same output directory
removes that stale diagnostic. `output_parity.csv` identifies the first
divergent timestep and date, while `biomass_parity.csv` records the checkpoint
comparisons. Results should be written outside the repository.

`phase_summary.csv` reports the complete independent biomass-validation rerun
in separate `validation_*` columns. The measured simulation therefore contains
no checkpoint traversals or validation-driven garbage collection.
Biomass totals are summed in stable PlantSimEngine object-ID order so exact
parity is not defeated by harmless object traversal-order roundoff.

Start or connect a Kaimon session using the XPalm `test` project, then evaluate:

```julia
include(joinpath(dirname(dirname(pathof(XPalm))), "benchmark", "vpalm_geometry_performance.jl"))
result = run_vpalm_geometry_benchmark(
    "/tmp/xpalm-vpalm-geometry-benchmark";
    nsteps=40,
)
```

Use `nsteps=4160` for the full reference scenario. Both variants are first
warmed for 128 days, then measured once in the fixed order `false`, `true`, in
blocks of 128 days. Consequently this runner is designed for a paired regression
comparison, not for publication-quality timing statistics. Lifecycle paths that
first occur after day 128 can still include their first-use compilation cost.

For a fully warmed comparison, pass `warmup_steps=4160`. Use
`order=(true, false)` for the BA half of an AB/BA check; write each order to a
different output directory. The selected warm-up length and measurement order
are recorded in `environment.csv`.

`sampled_peak_pse_objects` and `sampled_peak_mtg_nodes` are sampled at the end of
each 128-day block; they are not exact daily maxima. Retain `environment.csv`
with reported results: it records package revisions and dirty state, active
project and manifest fingerprint, Julia and machine information, seed, dates,
warm-up and sample order.
