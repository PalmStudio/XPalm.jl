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

## Scope and ownership

This benchmark measures the observational cost of maintaining the explicit
XPalm--VPalm architecture. It does not measure coupled mesh materialization or
light-interception feedback. XPalm owns organ lifecycle and coupling, VPalm owns
the shared biomechanical reconstruction, and PlantGeom should only receive a
generic optimization when profiling shows that the same improvement benefits
other mesh consumers.

## Reference result

The clean 4,160-day comparison at production head `ee2a20b` used Julia 1.12.1
with 10 threads on an Apple M3, PlantSimEngine `771894cd`, PlantGeom `9d682ef`,
and manifest SHA-256
`ddb56df467345f4cb462cb2b08ba4964df02d37f8c9da4cfc107723369b21802`.

| Metric | `architecture=false` | `architecture=true` |
|---|---:|---:|
| Simulation time | 13.130 s | 37.991 s |
| Allocated bytes | 8.934 GB | 12.205 GB |
| Final PlantSimEngine objects | 1,197 | 1,197 |
| Final MTG nodes | 1,197 | 18,673 |
| Sampled peak MTG nodes | 1,197 | 26,015 |

Explicit architecture costs 2.893 times the simulation time and 1.366 times
the allocated bytes. Against the original architecture-on baseline of
569.015 s and about 2.529 TB, the final implementation is 14.98 times faster
and allocates 99.52% fewer bytes. All 87,360 physiological comparisons and 363
structural-biomass comparisons are exactly equal between the two variants.

### Architecture-off non-regression

The production source at `cbbcfcd` (unchanged by the later benchmark-only
commit `2caa073`) was compared with `3d-architecture@bb2a0cc` in two fresh
Kaimon-controlled Julia sessions. Each session loaded the same lazy benchmark
runner, warmed only `architecture=false`, and confirmed that VPalm remained
unloaded. Six sequential AB/BA pairs gave:

- median time: 13.381 s on the base and 13.451 s on the head;
- paired head/base ratios from 0.9912 to 1.0127;
- geometric-mean ratio 1.0032 and median ratio 1.0058;
- exact-enumeration paired bootstrap 95% upper bound 1.0090 for the geometric
  mean, below the 1.02 non-regression limit;
- median allocation ratio 1.0000053, ranging from 0.999992 to 1.000025;
- identical output SHA-256
  `397a9cb18978721be03b0581b4c73b768a8dd3485947175378aa0826d14c488f`,
  1,197 PlantSimEngine objects, and 1,197 MTG nodes in every retained run.

An earlier ten-pair result from long-lived processes is not used for this gate:
including the old runner loaded VPalm before the architecture-off measurement
and confounded the comparison with different compilation and method-table
state. Lazy loading in the current runner fixes that protocol defect.

## Correctness contracts

Performance changes must retain:

- exact equality of the 21 physiological series and 11 biomass compartments;
- deterministic topology, attributes, random-number state and pruning;
- one-shot removal of pruned descendants from both the MTG and any registered
  PlantSimEngine objects;
- finalized leaflet profiles at rank 2 while the rachis pose may keep evolving;
- merge-scale topology, surface area and barycenter conservation;
- the established sequential raster-section biomechanics semantics.

The focused suite covers allocation parity, dynamic MTG lifecycle, pruning,
deterministic reconstruction, generic numeric behavior, and mesh/topology
invariants. The full 4,160-day benchmark remains a manual regression gate and
is not run in CI.

## Interpretation and deferred work

Timings are paired regression evidence, not publication-quality statistics,
and peak topology counts are sampled every 128 days. The coupled simulation
currently updates MTG geometry without materializing meshes. Mesh area and the
physiological leaf area used by Beer interception are deliberately separate;
mesh area must not feed that interception model until the scientific contract
is implemented and validated.

Event-driven lifecycle updates, one-shot pruning, and reusable sequential bend
workspaces are retained. Persistent topology caches, a PlantGeom optimization
branch, GPU work, and broader mesh caching are deferred until a measured
repeated mesh consumer justifies their complexity.

## Visual-reference maintenance

Keep three visual checks distinct: the structural 120-emitted-leaf VPalm
oracle, the five-date coupled XPalm--VPalm reconstruction, and the exact
145-emitted-leaf standalone CI raster. Replace the raster only after both the
numeric invariants and a human visual review pass; record the accepted fixture
hash with the change rather than a temporary output path.
