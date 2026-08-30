# XPalm–VPalm geometry performance goal

> Temporary working document. Keep it during the optimization work, update it
> after every measured change, then remove it before merging the completed work
> or convert the useful parts into permanent developer documentation.

## Working context

- Branch: `codex/geometry-performance`
- Base: `3d-architecture` at `bb2a0cc`
- Scope: dynamic VPalm architecture and geometry used by XPalm, plus shared
  VPalm and PlantGeom code when profiling shows that ownership belongs there.
- First priority: CPU performance and allocation reduction.
- Non-goal for this first phase: changing XPalm physiology or feeding mesh area
  back into light interception.

## Main objective

Make the explicit XPalm–VPalm reconstruction fast enough to be used routinely
without changing the simulated plant or the reconstructed palm.

The optimized implementation must preserve:

1. XPalm physiological outputs while architecture is only an observer;
2. the botanical topology and lifecycle of leaves and their children;
3. rachis, petiole and leaflet dimensions;
4. local and global positions, orientations and transformations;
5. deterministic reconstruction for a fixed random seed;
6. the standalone VPalm path that builds palms from configuration files.

The coupling already calls functions from the shared `VPalm` module. Therefore,
an optimization should be implemented in those shared functions whenever it is
valid for both standalone VPalm and XPalm–VPalm. Coupling-specific scheduling or
state belongs in the XPalm geometry model. Generic mesh operations belong in
PlantGeom and should be developed on a separate PlantGeom branch with its own
tests if profiling demonstrates that they are the bottleneck.

## Initial measured baseline

The first reference is one warmed, same-machine A/B run over 4,160 daily time
steps. It is a directional baseline, not a permanent absolute threshold. Every
performance comparison must rerun both variants in the same session and record
the environment.

| Metric | `architecture=false` | `architecture=true` | Difference |
|---|---:|---:|---:|
| Simulation time | 62.14 s | 569.01 s | 9.16 times slower |
| Allocated memory | 11.47 GB | 2.529 TB | 220.47 times more |
| Garbage-collection time | 0.54 s | 296.29 s | 52.1% of architecture runtime |
| PlantSimEngine objects | 1,197 | 1,197 | identical |
| MTG nodes | 1,197 | 18,673 | 15.6 times more |

The 17,476 additional MTG nodes are:

- 40 petioles;
- 600 petiole segments;
- 40 rachises;
- 4,000 rachis segments;
- 12,796 leaflets.

All 87,360 compared physiological values (21 daily series over 4,160 days) were
exactly identical. This confirms that, today, explicit architecture does not
feed back into physiology. The extra nodes are MTG geometry nodes rather than
additional PlantSimEngine simulation objects.

The timed A/B simulation exercised dynamic topology and property updates, but
not downstream mesh materialization by `add_geometry!`. Mesh construction must
therefore be benchmarked as a separate future phase; it does not explain the
main 569 s simulation baseline.

The current final-state mesh diagnostic also found:

- physiological opened-leaf area: 382.98 m2;
- opened-leaflet mesh area: 173.37 m2;
- mesh/physiological area ratio: 0.453;
- all visible mesh area: 217.17 m2;
- 12,796 leaflets mapped and none unmapped.

This area mismatch must be resolved scientifically before mesh area is connected
to Beer-law light interception. It is deliberately outside the performance
changes in this branch.

## Correctness contracts

### Physiology

- Until mesh feedback is introduced explicitly, `architecture=true` and
  `architecture=false` must give the same daily physiological outputs.
- The architecture-off path must remain unchanged and must not regress by more
  than measurement noise.
- Performance refactors must not change carbon allocation, leaf area, LAI,
  yield, maintenance respiration or organ biomass.

### Leaf lifecycle

Validation must cover the full sequence rather than only the final palm:

1. internal primordium;
2. first visible leaf / spear;
3. opening;
4. post-opening rachis elongation up to the rank defined by the biological
   model;
5. mature leaf;
6. death and pruning;
7. repeated steps after pruning.

Once a leaf's explicit topology has been created, an update must not silently
add, remove or replace its leaflets. Local leaflet lengths, widths and attachment
positions must remain stable when the biological model says growth has stopped.
Rachis elongation and changes in leaf, rachis and leaflet orientation may still
move the existing geometry. These local dimensions and global transformations
must be tested separately.

Pruning must leave the intended snag, remove petiole, rachis, segment and
leaflet descendants once, and prevent later reconstruction of the pruned leaf.
Repeated pruning updates must be inexpensive no-ops.

### Randomness

- A fixed seed must reproduce the same topology, attributes and geometry.
- Optimization must not consume extra random draws on no-change days.
- If event-based scheduling changes the historical random stream, use stable
  per-organ random state or document and test the intentional migration before
  accepting it.

### Standalone VPalm

- `build_mockup(parameters; merge_scale=...)` and the YAML configuration path
  must remain supported.
- Shared-kernel optimizations must be tested through both standalone VPalm and
  XPalm–VPalm.
- `merge_scale = :none`, `:leaflet`, `:leaf` and `:plant` must retain their
  documented topology/queryability trade-offs.

## Measurement protocol

### Reproducibility

For every benchmark batch, record:

- XPalm, PlantSimEngine, MultiScaleTreeGraph and PlantGeom revisions and paths;
- Julia version, thread count, operating system and hardware;
- parameter file, simulation dates, random seed and architecture option;
- warm-up policy, sample count and sample order;
- elapsed time, allocated bytes, GC time and peak node/object counts.

Use interleaved or ABBA ordering for before/after runs. Do not compare a cold
first run with a warmed second run. Store machine-readable CSV or JSON results
outside the source tree unless they are intentionally promoted to test fixtures.

Separate these costs when possible:

1. package/session setup and compilation;
2. XPalm physiological simulation;
3. VPalm topology creation;
4. biomechanical calculations;
5. local mesh construction;
6. global transformation updates;
7. scene materialization and output writing.

### Benchmark layers

#### A. Kernel microbenchmarks

Measure time and allocations for representative young, opening and mature
leaves:

- `compute_properties_leaf!`;
- `biomechanical_properties_rachis`;
- `bend`;
- `build_leaf`;
- `update_petiole!`;
- `update_rachis_angles!`;
- `update_leaflet_angles!`;
- leaflet local extrusion and `RefMesh` construction;
- first and repeated `remove_leaf_geometry!` calls.

#### B. Lifecycle event benchmarks

Benchmark one simulation step for each distinct event:

- no relevant architecture change;
- first visible leaf and first topology creation;
- leaf opening;
- rank change with existing geometry;
- mature leaf with no change;
- first pruning;
- already-pruned leaf.

This layer should show which work is truly event-driven and which work is still
repeated daily.

#### C. Standalone VPalm benchmarks

- Build the existing deterministic reference palm from configuration.
- Benchmark all supported merge scales separately.
- Add a representative palm of about 120 emitted leaves, corresponding roughly
  to five years at one emitted leaf every 15 days.
- Measure topology/property construction separately from geometry and rendering.

#### D. Coupled XPalm–VPalm benchmarks

- Short lifecycle scenario that exercises creation, update and pruning.
- Five-year scenario with approximately 120 emitted leaves for visual and
  structural comparison with standalone VPalm.
- Full 4,160-step reference simulation for end-to-end performance and exact
  physiology parity.

#### E. PlantGeom and scene benchmarks

Only after profiling points to this layer, measure:

- profile extrusion and reference-mesh construction;
- transformation composition and application;
- `merge_children_geometry!` by merge scale;
- `prepare_scene`, area and barycenter calculation;
- materialization of cached reference meshes into scene meshes.

## Work plan

### Phase 0 — Freeze reproducible baselines and oracles

- [x] Add a controlled benchmark runner with fixed parameters and random seed.
  `benchmark/vpalm_geometry_performance.jl` records separate setup, simulation
  and output-materialization costs, exact 21-series parity, topology, sampled
  object/node peaks, dependency revisions/dirty state and the active manifest.
- [x] Capture the current short, multi-date five-year and 4,160-step results.
- [x] Save a compact deterministic fingerprint for one dynamic leaf: class
  counts, identities, parent relations and local leaflet dimensions/profiles.
- [x] Confirm exact architecture-off/on observer parity in a fresh three-day
  test for LAI, leaf area and carbon assimilation. The benchmark smoke test also
  preserves all 21 canonical series exactly. At commit `c582c6a`, the full
  4,160-step run preserves all 87,360 values exactly; rerun this gate after any
  later runtime-affecting change.
- [x] Record the current standalone VPalm reference reconstruction, including a
  fixed-seed approximately 120-emitted-leaf palm, per-merge-scale topology,
  canonical mesh hashes, dimensions, bounds, area and build/materialization
  costs. The dynamic standalone parameter path remains a documented gap.
- [x] Define explicit tolerances for the first permanent floating-point mesh
  contracts: local vertices/bounds at 1e-12 m, surface at 1e-12 relative
  tolerance, and oriented merge comparison after 1e-10 m quantization.

CI dependency resolution is now reproducible from the pinned remote
PlantSimEngine and PlantGeom commits. Julia 1.10 still cannot use `[sources]`
when Aqua recreates a Project.toml-only environment for its persistent-task
probe, so only that one Aqua probe is version-gated on 1.10; the other nine
Aqua checks remain enabled, and the probe remains enabled from Julia 1.11.
The Ubuntu reference-regression mismatch is inherited from the scientific
carbon/respiration changes on `3d-architecture`: the former local dependency
failure had hidden it. This geometry-performance branch must not silently
rewrite the v0.6.1 scientific reference.

### Phase 1 — Profile before changing implementation

- [x] Profile daily no-change steps, leaf creation, rank updates and pruning
  separately.
- [x] Attribute the simulation-only allocations to XPalm scheduling, VPalm
  biomechanics and MTG traversal/construction. Standalone materialization was
  profiled separately; coupled mesh materialization remains a later layer.
- [x] Measure whether node creation or per-day recomputation dominates.
- [x] Confirm how often each geometry event occurs in a controlled 400-day run.
- [x] Rank the current simulation-only hotspots by cumulative time and allocated
  bytes.

Current code-reading hypotheses to test, not yet accepted conclusions:

- the geometry model recomputes final rachis length and leaf properties before
  deciding whether visible geometry needs an update;
- phyllotactic random values are sampled on daily calls rather than only at the
  appropriate lifecycle event;
- rank changes traverse all leaflet descendants to update their angles;
- the biomechanical path allocates several small vectors and coordinate arrays
  on every call;
- `bend` repeatedly calls an inertia calculation that constructs an
  approximately 100 by 100 numerical section grid for 15 iterations and five
  rachis sections;
- when meshes are materialized later, every leaflet creates a new extruded
  `RefMesh`, even when its local geometry could be retained between global pose
  updates.

The warmed 40-day smoke benchmark currently takes 0.0508 s and allocates
45.17 MB without architecture, versus 0.0651 s and 51.51 MB with architecture;
all 840 retained values are exactly identical. This is only a runner validation,
not an end-to-end performance conclusion. Its environment fingerprint also
correctly reports that the active sibling PlantSimEngine checkout is dirty, so
fresh full-run results must retain that dependency state or use a committed,
pinned revision before being treated as canonical.

Fresh 400-day event profile after the first optimization slices:

- 8,557 geometry calls comprise 7,900 no-event calls (92.32%), 35 builds, 126
  early unfolding updates, 31 final rank-2 updates and 465 mature updates;
- no-event calls cost about 0.529 microseconds and 80 bytes, confirming that the
  remaining cumulative cost comes from real lifecycle events rather than daily
  reconstruction;
- build, early, rank-2 and mature reference events cost respectively 4.31 ms /
  823 kB, 2.10 ms / 544 kB, 1.44 ms / 517 kB and 0.320 ms / 378 kB;
- scientific kernels account for 59.8% of instrumented step time, execution-plan
  compilation 16.5% and binding refresh 14.9%; repeated pruning is effectively
  allocation-free;
- rachis biomechanics contributes about 370.7 kB per transition, an estimated
  230.6 MB or 44.1% of all allocations in the 400-day run. A reusable rachis
  workspace is therefore the next measured optimization target.

### Phase 2 — Make scheduling genuinely event-driven

- [x] Introduce the first explicit lifecycle state: existing
  `is_reconstructed` plus `geometry_removed` for one-shot pruning. Additional
  state is only justified if later profiling needs it.
- [ ] Skip geometry work completely on days when no relevant input changed,
  before MTG traversal, allometry recomputation or random draws.
- [x] Move the expensive rank-dependent biomechanics behind rank-change
  detection.
- [x] Compute stable organ properties and random attributes once at the correct
  lifecycle event.
- [x] Avoid revisiting already-pruned descendants and registered geometry
  objects.
- [x] Update leaflet deployment profiles through their final rank-2 state, then
  freeze them. Rank-3 and later transitions still update petiole and rachis
  geometry without traversing or rebuilding leaflet profiles.
- [x] Keep the safe build/update path for genuine rank or topology changes.
- [x] Test unchanged properties/RNG and repeated pruning transitions. The full
  visible-to-open-to-rank-3 scenario remains a Phase 0 validation task.

Candidate state must be derived from biological inputs, not only timestamps. A
cache key may need rank, visibility/opening state, alive/pruned state, rachis
length, insertion angles and other inputs identified by dependency tracing.

First measured event-gating slice:

- internode synchronization over 100,000 warmed calls: 13.91 ms and 4.8 MB
  before, 7.88 ms and zero allocations after;
- unchanged leaf path over 100,000 warmed calls: 30.89 ms and 8.0 MB before,
  29.26 ms and 4.8 MB after;
- `XEuler` is now sampled once per internode, while the stochastic C-point
  angle is updated only when rank or expected rachis length changes;
- pruning records `geometry_removed` on PlantSimEngine status, so both MTG
  descendants and any registered geometry objects are removed exactly once.

The remaining steady-state allocations must be profiled after the integrated
benchmark; this first slice deliberately preserves daily synchronization of
internode dimensions and rank.

Leaflet deployment follow-up:

- rank 2 still replaces and finalizes all deployment profiles;
- rank 3 and rank 4 preserve the exact scalar leaflet state and the identity of
  all four profile arrays, while petiole and rachis dimensions continue to
  change;
- a 154-leaflet warmed update drops from median 2.94 ms and 594,456 bytes at the
  final unfolding event to 0.541 ms and 377,568 bytes on a mature transition;
- the skipped leaflet phase consumes no random draws. Rachis biomechanics still
  advances the supplied random stream by design and remains a separate
  lifecycle-RNG risk to assess.

### Phase 3 — Reduce allocations in VPalm biomechanics

- [ ] Move literal constant arrays out of hot functions.
- [x] Replace raster matrices, point clouds and temporary coordinate
  comprehensions in section inertia with scalar raw-moment accumulation.
- [ ] Let `bend` accept the point representation already produced by VPalm
  instead of splitting and rebuilding x/y/z arrays.
- [x] Hoist the five invariant raster-section moments and torsional interpolation
  outside the 15-iteration `bend` loop while preserving the historical section
  predicates.
- [x] Validate the raw-moment kernel against the former raster implementation
  across all five shapes, two dimension ratios and three angles.
- [ ] Evaluate continuous analytical section formulas as a separate scientific
  change. They are not acceptable for this compatibility optimization because
  they move the bend fixture by up to 1.14 cm and 0.285 degrees.
- [x] Reuse the bending-inertia, coordinate-conversion, reconstructed-point and
  conserved-segment-length buffers across iterations. Other `bend` work arrays
  remain candidates.
- [x] Keep one sequential-execution workspace on `GeometryModel` for the
  cumulative flexion/torsion buffers used by mature rachis transitions. The
  public standalone `bend` path remains generic and workspace-free.
- [ ] Reduce repeated unit conversions and dictionary lookups inside loops while
  preserving the public Unitful API.
- [ ] Consider a typed, unit-normalized internal kernel with explicit conversion
  at the boundary.
- [x] Benchmark allocations, timings and numerical parity for the first inertia
  optimization.

First measured biomechanics slice:

- five-section inertia sweep: 15,782,880 bytes to 2,688 bytes and median
  2.520 ms to 0.149 ms;
- complete existing `bend` fixture: 168,446,304 bytes to 1,135,888 bytes and
  about 29.425 ms to median 0.428 ms;
- 30 shape/dimension/angle parity cases: maximum relative flexion error
  `5.30e-15`, torsion error `6.92e-16`, and exactly identical area;
- existing bend CSV reference unchanged and passing.

Second measured biomechanics slice:

- complete existing `bend` fixture: 1,135,888 bytes to 654,272 bytes, a further
  42.4% reduction and 99.61% below the original implementation;
- median runtime over 201 warmed calls: 0.437 ms, effectively unchanged from
  the first optimized slice;
- public coordinate-conversion helpers retain their results, while private
  in-place kernels reuse distance, angle and point buffers inside `bend`;
- coordinate, inertia and bend targeted suites pass 17/17, 130/130 and 15/15.

Third measured biomechanics slice:

- a warmed mature rachis transition falls from 377,552 bytes and median
  318.5 microseconds to 124,128 bytes and 297.4 microseconds by reusing the
  cumulative force, shear, moment, flexion and torsion buffers;
- allocations fall by 67.1%, while the complete rachis-segment state is exactly
  equal to the generic path and the next random draw remains identical;
- buffer identities are retained across rank-3 and rank-4 transitions, and the
  already-frozen leaflet profiles keep their array identities;
- fresh geometry-event, bend/CSV, geometry-contract and rachis/geometry suites
  pass. A workspace belongs to one sequential geometry execution; concurrent
  calls on the same model instance require independent workspaces.

Coupled multi-date reconstruction validation after this slice:

- one continued simulation was inspected at 365, 730, 1,095, 1,460 and 1,825
  days, with numerical summaries and a rendered image at every checkpoint;
- the scenario starts with one phytomer and reaches 173 phytomers at five years,
  equivalent to about one new phytomer every 10.6 days. The 109- and
  142-phytomer checkpoints bracket the requested approximately 120 count;
- at 1,460 days, mean rachis and petiole lengths are within 2.6% and 4.1% of
  the standalone static-120 reference, but the crown already reaches z=-1.49 m;
- at five years, 58 living geometric leaf subtrees contain 14,470 leaflets,
  close to 53 and 14,640 in the static reference. Mean rachis length is 4.31 m
  instead of 3.66 m, and the lowest rank-50 leaflet reaches z=-1.61 m;
- the visual and numerical residual therefore points to mature flexion/angle
  mechanics and age/count matching, not a drift introduced by the performance
  refactors or a simple global unit error;
- all 88 final pruned leaves have zero descendants, and no dynamic petiole,
  rachis, segment or leaflet is a PlantSimEngine simulation object;
- opened-leaf mesh area is only 61-67% of XPalm physiological leaf area after
  year three. It must not replace `leaf_area` without a separate scientific
  correction. The year-one ratio above one also confirms strong age dependence;
- after the cold first-year chunk, the successive 365-day chunks take 2.61 to
  5.16 seconds in the clean pinned-dependency environment. All CSV and PNG
  artifacts remain outside the repository under `/private/tmp`.

Final geometry-correctness follow-up at `e9af898`:

- every leaf now records whether its leaflet profiles have reached the final
  rank-2 unfolding state. A legacy MTG without the marker, or a direct jump
  from an immature rank to rank 3 or above, receives exactly one final
  unfolding update before entering the mature fast path;
- the biomechanical small-displacement guard is now independent of warning
  verbosity, preserves the sign while clamping flexion and torsion, and the
  terminal rachis segment now copies the actual penultimate segment angles;
- the standalone skeleton now consumes fresh-rachis masses in the same
  old-to-young order as configured rachis lengths. The former reverse order
  assigned the lightest rank-1 mass to the oldest leaf and made the lower crown
  artificially flat;
- focused event, pruning, unfolding, bend, angle-limit, rachis-terminal and
  static mass-order tests pass. The short warmed 400-day observer check retains
  all 8,400 values exactly (`maximum absolute difference = 0`): 0.568 s and
  234.30 MB without architecture versus 1.043 s and 374.97 MB with it;
- the corrected static 120-emitted-leaf reference retains exactly 21,263 MTG
  nodes, 53 geometric leaves, 14,640 leaflets, the former organ dimensions,
  278.110 m2 total mesh area and 219.606 m2 leaflet mesh area. Only pose changes
  as intended: the world-space lower bound moves from z=-0.060 m to z=-0.597 m
  when old leaves receive their correct heavier masses;
- the corrected 1,825-day coupled palm retains 21,780 MTG nodes, 58 geometric
  leaves, 14,470 leaflets, 239.252 m2 physiological leaf area, LAI 3.254 and
  271.376 m2 total mesh area. Its bounds remain close to the previous run,
  z=[-1.599, 8.002] m, so the guard and terminal-angle fixes do not introduce a
  gross reconstruction drift;
- the corrected static and coupled PNG files and machine-readable summaries are
  stored under `/private/tmp/xpalm-vpalm-corrected-validation-e9af898`. The
  static image reference must be reviewed and deliberately regenerated because
  the mass-order correction intentionally changes its pose; it must not be
  overwritten merely to silence the pre-existing image check.

Integrated 4,160-step result at `c582c6a`:

- the first identically ordered run, including lifecycle paths first compiled
  after the 128-day warm-up, takes 63.52 s without architecture and 61.85 s with
  architecture. The architecture-on value is 9.2 times faster than the original
  569.01 s baseline;
- architecture-on allocations fall from about 2.529 TB to 17.63 GB and GC from
  296.29 s to 1.08 s, while architecture-off remains near its original 62.14 s
  first-run baseline;
- a subsequent fully compiled AB/BA pair gives median 13.14 s and 8.94 GB
  without architecture, versus 38.57 s and 16.41 GB with architecture: 2.93
  times the runtime and 1.83 times the allocations;
- the warmed architecture-on runtime is 14.75 times faster and allocations are
  99.35% lower than the original architecture-on baseline. GC remains below
  3.4% of runtime;
- all 87,360 physiological values remain exactly identical in every pair;
- final PlantSimEngine object counts are 1,197 in both variants. The explicit
  MTG has 18,673 final nodes and a 26,015-node peak sampled at 128-day
  boundaries;
- the active PlantSimEngine checkout was at `771894cd` with tracked local
  changes, as captured by `environment.csv`. These timings must therefore be
  repeated against the eventual committed dependency revision.

The 128-day warm-up does not compile lifecycle paths that first occur later in
the eleven-year scenario. The durable runner now accepts `warmup_steps=4160`
and either `(false, true)` or `(true, false)` measurement order so future
results can distinguish first-run cost from fully warmed steady-state cost.

Fresh final A/B at `83b7350`, after a full 4,160-step warm-up of both variants:

- `architecture=false`: 13.231 s and 8.980 GB allocated;
- `architecture=true`: 38.540 s and 12.841 GB allocated;
- the remaining architecture overhead is 2.913 times the runtime and 1.430
  times the allocations;
- compared with the original 569.015 s / about 2.529 TB architecture baseline,
  this is 14.76 times faster with 99.49% fewer allocated bytes;
- all 87,360 retained physiological values are exactly equal, with maximum
  absolute difference zero for every series;
- final and sampled peak counts remain 1,197 PlantSimEngine objects, 18,673
  final MTG nodes and 26,015 sampled peak MTG nodes in architecture mode.

The machine was concurrently running another PlantSimEngine session, so these
absolute timings are not publication-quality. The within-process parity and
ratio remain valid, and the allocation improvement is independent of CPU load.

Fresh final A/B at `e9af898`, after the final unfolding, angle-guard and static
mass-order corrections and a full 4,160-step warm-up of both variants:

- `architecture=false`: 13.326 s and 8.953 GB allocated;
- `architecture=true`: 38.364 s and 12.870 GB allocated;
- architecture therefore costs 2.879 times the runtime and 1.438 times the
  allocations in this paired run, effectively unchanged from `83b7350`;
- all 87,360 retained physiological values remain exactly equal, with maximum
  absolute difference zero for all 21 daily series;
- final and sampled-peak structure remains 1,197 PlantSimEngine objects,
  18,673 final MTG nodes and 26,015 sampled-peak MTG nodes;
- against the original 569.015 s / about 2.529 TB architecture baseline, the
  final implementation remains 14.83 times faster with 99.49% fewer allocated
  bytes.

### Phase 4 — Reduce topology and traversal costs

- [ ] Measure repeated `descendants`/`traverse!` lookups during updates.
- [ ] Cache safe references or node identifiers for leaf geometry children.
- [ ] Preallocate or bulk-create predictable petiole, rachis and leaflet nodes
  if MultiScaleTreeGraph supports this without breaking identifiers or links.
- [ ] Avoid rebuilding topology when only transformations changed.
- [ ] Keep pruning correct for MTG nodes and any future PlantSimEngine objects.
- [x] Confirm that the current optimization preserves standalone merge-scale
  geometry: all four modes conserve the same canonical mesh at 1e-12 m.

Current registry audit: initial seed geometry is registered because it exists
before CompositeModel construction, while dynamically created geometry remains
MTG-only. No application targets petiole, rachis, segment or leaflet scales, so
registered geometry objects receive no scientific model calls. Pruning removes
both registered seed descendants and unregistered dynamic descendants. At day
400 the controlled run has 302 registered objects and 7,985 MTG nodes.

### Phase 5 — Cache local geometry; update pose separately

This phase targets later mesh reconstruction and 3D use; it is not expected to
remove the main simulation-only baseline cost measured above.

- [ ] Distinguish immutable local leaflet shape from mutable global placement.
- [ ] Construct each local leaflet mesh only when its dimensions/topology are
  first known, then retain it while only the transformation changes.
- [ ] Update transformations when the stem, rachis, rank or leaf angles move.
- [ ] Avoid transforming/materializing all vertices unless a downstream model
  actually requests a concrete scene mesh.
- [ ] Verify local mesh area, vertices/faces, bounding box and barycenter before
  and after caching.
- [x] Add a lightweight permanent mesh oracle before caching: one analytic
  leaflet plus a deterministic one-leaf mockup preserve finite coordinates,
  valid oriented faces, bounds, area and 700 oriented triangles across all four
  merge scales. The two intentional zero-area leaflet-tip faces are counted
  rather than rejected.
- [ ] Test whether families of identical shapes can share `RefMesh` instances;
  do not assume sharing is valid for leaflets with different dimensions.

PlantGeom already represents geometry as a shared `RefMesh` plus a per-node
transformation and materializes lazily. Prefer using that contract fully before
adding a new cache layer.

The dynamic XPalm coupling currently creates and updates geometric MTG nodes but
does not call `add_geometry!`; mesh materialization is still confined to the
standalone `build_mockup` path. Mesh caching therefore cannot improve the
current `architecture=true` simulation benchmark yet. It is groundwork for the
future opening/light-interception event and for standalone VPalm.

The first measured local-mesh slice now removes the temporary vector of segment
named tuples and allocates the four extrusion work arrays at their final size.
Exact path, normal, width, height, full-mesh and merged-fixture geometry is
preserved. On the warmed fixture, local extrusion falls from 4,720 B to 3,328 B
(-29.5%), one complete leaflet from 16,400 B to 15,152 B (-7.6%), and the tiny
12-leaflet palm from 500,424 B to 470,472 B (-6.0%). The permanent mesh oracle
passes 14/14 after the change. The gain is real but small at scene scale, so a
larger cache layer is not justified until a downstream model actually requests
repeated mesh materialization.

The merge-scale audit also found two contracts to resolve before freezing a
permanent reference: `:none` and `:leaflet` are currently operationally
identical, while `:plant` leaves every Internode mesh separate because Internode
is omitted from the final merge. Tests must describe the chosen semantics rather
than silently canonize the current documentation mismatch.

### Phase 6 — Consider PlantGeom changes only with evidence

- [ ] Profile generic transformation, extrusion, merge and scene-preparation
  operations independently.
- [ ] If a generic PlantGeom operation is a confirmed bottleneck, create a
  dedicated PlantGeom branch and benchmark it with PlantGeom's own tests.
- [ ] Keep XPalm-specific lifecycle and biological state out of PlantGeom.
- [ ] Pin the tested PlantGeom revision in the XPalm validation report.

Potential generic experiments include in-place or batched vertex transforms,
lower-allocation extrusion, cached area/barycenter summaries and avoiding an
unnecessary full-scene merge. Each needs cross-application tests because a
PlantGeom optimization affects more than XPalm.

### Phase 7 — GPU go/no-go, deferred

Do not start with GPU work. Reconsider it only if CPU profiling after Phases 2–6
shows that large, repeated vertex operations remain dominant.

A GPU experiment must demonstrate:

- enough triangles and repeated operations to amortize transfers;
- reusable device-resident mesh data;
- a clear CPU fallback;
- bounded numerical differences;
- end-to-end improvement, not only a faster isolated kernel.

Likely GPU candidates, if justified, are batched transformations or downstream
radiation calculations. Botanical topology management and small biomechanical
systems are expected to remain CPU work unless measurements show otherwise.

## Validation matrix

| Layer | Required checks | Primary oracle |
|---|---|---|
| Biomechanics | bend points, distances and angles | existing CSV references plus numerical tolerance |
| Leaf properties | rachis/petiole dimensions, leaflet lengths, widths and attachment positions | pre-change structured snapshot |
| Topology | symbols, counts, node identities, parent/child links | exact equality |
| Lifecycle | visible/open/rank-change/mature/pruned states | event snapshots and invariants |
| Local geometry | vertices, faces, area, bounding box, barycenter | numerical summaries and selected mesh equality |
| Global geometry | transformed landmarks and orientations | numerical coordinates and angles |
| Standalone VPalm | config-driven deterministic palm for each merge scale | current tests and reference reconstruction |
| Coupled five-year palm | approximately 120 emitted leaves | like-for-like VPalm visual and structural reference |
| Full coupling | 21 daily physiological series over 4,160 steps | exact equality while architecture is observational |
| Performance | time, allocations, GC and peak nodes | same-session interleaved benchmark |

Images are useful for detecting gross reconstruction drift, but they are not
sufficient alone. A valid change must pass numerical topology, dimension and
transformation checks as well as selected image references. Never update a
reference image merely to make an unexplained difference pass.

Existing tests to preserve and extend include:

- deterministic standalone skeleton and exact node counts;
- the standalone palm reference image;
- bend/unbend CSV comparisons;
- geometry unit checks;
- dynamic rachis age allometry;
- preservation of leaflet topology and dimensions during rachis elongation;
- snag geometry and pruning behavior.

Known gaps found during the initial audit:

- the canonical deterministic standalone configuration checks 20,994 total
  nodes, but does not yet protect a structured fingerprint of parent/child
  edges, ranks and key attributes;
- current transformation checks cover internodes, petioles and rachises, while
  the leaflet geometry test is commented out;
- there is no automated check of leaflet mesh area, vertex/face counts,
  non-degenerate triangles, bounding boxes or `prepare_scene` output;
- merge-scale tests do not yet prove conservation of surface across `:none`,
  `:leaflet`, `:leaf` and `:plant`;
- coupled tests cover initial reconstruction and pruning, but not one forced
  internal-to-visible-to-open-to-rank-3 lifecycle with stable node identities;
- the 4,160-step release regression currently protects `architecture=false`.
  A short exact false/true CI test and durable full A/B runner now exist, but a
  scheduled full test is not yet configured.

Standalone reference added during this work:

- a fixed-seed 120-emitted-leaf static configuration produces 21,263 nodes,
  including 14,640 leaflets, and a mesh with 465,302 vertices, 671,076 triangles
  and 278.110 m2 total triangle area;
- `:none`, `:leaflet`, `:leaf` and `:plant` conserve the canonical unordered
  mesh at 1e-12 m, including bounds and area. Eager `:leaf`/`:plant` merging
  roughly doubles build time and allocations, while reducing later
  `prepare_scene` cost;
- `:none` and `:leaflet` are currently operationally identical;
- `default_parameters(type="dynamic")` cannot use the standalone skeleton path
  because `mtg_skeleton` requires the absent `rachis_fresh_weight` key;
- the existing 145-leaf image reference reaches 24.673 dB PSNR in the current
  rendering environment, just below the default 25 dB threshold. Numeric mesh
  references are needed to distinguish geometry drift from rendering drift.

Permanent lightweight mesh guardrails added during this work:

- one analytic local leaflet retains 12 vertices, 12 oriented faces, a
  0.0115 m2 surface and exactly two intentional zero-area tip faces;
- a deterministic one-leaf fixture contains 432 vertices and 700 triangles,
  with exact oriented-triangle conservation across `:none`, `:leaflet`, `:leaf`
  and `:plant` after 1e-10 m coordinate quantization;
- the focused test passes 14/14 and takes about 0.226 seconds once compiled.

## Performance acceptance criteria

Correctness gates are mandatory; speed cannot compensate for reconstruction
drift.

For each optimization commit:

- report the affected benchmark and before/after values;
- require no meaningful regression in unrelated benchmark layers;
- target at least 10% less time or 20% fewer allocations in the measured hot
  slice, unless the commit is an enabling refactor;
- keep the architecture-off end-to-end time within 2% on repeated same-session
  measurements.

Branch-level milestones:

1. First milestone: remove daily no-op geometry work and sharply reduce GC.
2. Main target: make the 4,160-step architecture-on run at least three times
   faster than the 569 s baseline and reduce allocations by at least one order
   of magnitude.
3. Stretch target: bring architecture-on runtime within twice the
   architecture-off runtime, allocations within three times the architecture-off
   value, and GC below 10% of runtime without reducing reconstruction detail.

These ratios must be recalculated from fresh paired runs; the absolute numbers
above are not portable across machines or dependency revisions.

## Commit and review cadence

Keep changes small and reviewable. A likely sequence is:

1. benchmark and validation harness;
2. event/state gating;
3. pruning no-op fast path;
4. biomechanics allocation reduction;
5. topology/traversal reduction;
6. local mesh and transformation caching;
7. optional PlantGeom work in its own branch;
8. full validation and cleanup.

Every performance commit must include or update its targeted regression test and
record its benchmark delta in the pull request. Avoid mixing scientific model
changes with performance changes.

## Decision log

| Date | Decision | Evidence | Consequence |
|---|---|---|---|
| 2026-08-30 | Start with CPU profiling and allocation reduction | architecture-on allocates about 2.53 TB and spends about 52% of runtime in GC | GPU work deferred |
| 2026-08-30 | Keep physiology observational in this branch | all 87,360 A/B values are currently identical | mesh-to-LAI feedback is a separate scientific change |
| 2026-08-30 | Validate local shape separately from global pose | leaf topology/dimensions can remain fixed while rachis and leaf angles move | cache local meshes, update transformations |
| 2026-08-30 | Optimize shared VPalm functions when possible | standalone and coupled paths call the same VPalm module | test both entry points |
| 2026-08-30 | Make geometry updates event-driven and pruning one-shot | unchanged calls advanced RNG and repeated pruning revisited the subtree | store lifecycle state in PlantSimEngine status and preserve organ-level random traits |
| 2026-08-30 | Preserve rasterized section mechanics for the first inertia optimization | continuous formulas change the current bend reference materially | accumulate and rotate raw raster moments, then hoist them outside the iteration loop |
| 2026-08-30 | Reuse coordinate work buffers inside `bend` | the remaining full-fixture allocation was 1.14 MB despite the inertia rewrite | keep the public API and numerical fixture while using private in-place kernels |
| 2026-08-30 | Freeze leaflet deployment profiles after rank 2 | the existing unfolding kernel reaches its final state at rank 2, while later transitions still alter petiole and rachis geometry | skip mature leaflet traversal without freezing whole-leaf pose updates |
| 2026-08-30 | Keep cumulative rachis buffers on the geometry model | mature transitions still allocated about 378 kB, dominated by repeated integration arrays | reuse one sequential workspace while keeping standalone `bend` generic and exact |
| 2026-08-30 | Compare merged meshes by oriented coordinate triangles | merge order and node topology differ by scale, and leaflet tips intentionally contain degenerate faces | quantize coordinates, allow cyclic face rotations only, and count expected zero-area faces |
| 2026-08-30 | Keep mesh area observational after multi-date validation | opened mesh area is 61-67% of physiological area after year three and the mature coupled crown extends far below the standalone reference | investigate area allometry and mature flexion separately before any light-feedback coupling |
| 2026-08-30 | Preallocate local leaflet extrusion arrays without adding a persistent mesh cache | the isolated extrusion allocation falls 29.5%, but the tiny-palm gain is only 6.0% and coupled simulations do not materialize meshes | keep the exact lightweight optimization and defer broader caching until a real repeated consumer exists |
| 2026-08-30 | Keep the full A/B benchmark in-repository but its generated data outside the tree | the previous driver was an external artifact and could not fully fingerprint the active environment | provide a fixed-seed 21-series runner and retain machine-readable results with each reported run |
| 2026-08-30 | Report first-run and fully warmed full-scenario timings separately | a 128-day warm-up leaves later lifecycle compilation in the first measured pair | retain the representative first-run comparison and validate steady-state overhead with AB/BA order |
| 2026-08-30 | Store the final leaflet deployment state explicitly | direct immature-to-rank-3 transitions and legacy MTGs otherwise skip the final rank-2 profile | perform one compatibility update, then retain the mature fast path |
| 2026-08-30 | Apply signed biomechanical angle limits independently of verbosity | `verbose=false` formerly disabled the documented `force=true` guard | warnings remain optional while the scientific guard remains active |
| 2026-08-30 | Align static rachis masses with configured leaf-rank order | lengths and masses are both specified oldest-to-rank-1 but only masses were popped from the opposite end | restore the intended lower-crown loading and require deterministic rank-order tests |

## Deferred scientific work

The following topics are related but should not be mixed into an optimization
commit unless a correctness bug blocks performance work:

- resolving the physiological-area versus mesh-area discrepancy;
- defining exactly when mesh area starts contributing to Beer-law interception;
- introducing 3D light interception feedback;
- revising age-dependent allometries;
- recalibrating biomechanical parameters or fresh-mass conversions.

For a later Beer-law implementation, the intended hypothesis to test is that an
individual leaf's intercepting area is measured once when it opens, remains
constant until death/pruning, and is then removed. A full 3D light model still
needs current meshes or transformations because leaf and leaflet positions can
change even when their local areas do not.

## Definition of done

- [ ] All mandatory correctness and determinism gates pass.
- [ ] Standalone VPalm and coupled XPalm–VPalm reconstructions remain equivalent
  to their approved references.
- [x] The five-year approximately 120-leaf palm has been checked numerically and
  visually at several dates, not only at the final date.
- [x] Full coupled physiology remains identical while architecture is an
  observer.
- [x] Fresh paired benchmarks meet the main performance target or document a
  measured residual bottleneck and justified next step.
- [ ] Any PlantGeom change is independently tested and reviewed in PlantGeom.
- [ ] GPU work is either rejected with measurements or isolated behind a tested
  CPU fallback.
- [x] Temporary benchmark artifacts are removed or archived outside the source
  tree.
- [ ] This temporary file is removed or converted into permanent documentation
  before the optimization pull request is merged.
