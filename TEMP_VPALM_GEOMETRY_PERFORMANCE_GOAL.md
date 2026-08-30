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
- [ ] Capture the current short, five-year and 4,160-step results.
- [x] Save a compact deterministic fingerprint for one dynamic leaf: class
  counts, identities, parent relations and local leaflet dimensions/profiles.
- [x] Confirm exact architecture-off/on observer parity in a fresh three-day
  test for LAI, leaf area and carbon assimilation. The benchmark smoke test also
  preserves all 21 canonical series exactly. The full 4,160-step rerun remains
  required.
- [ ] Record the current standalone VPalm reference reconstruction.
- [ ] Define explicit tolerances for floating-point geometry comparisons.

### Phase 1 — Profile before changing implementation

- [ ] Profile daily no-change steps, leaf creation, rank updates and pruning
  separately.
- [ ] Attribute allocations to XPalm scheduling, VPalm biomechanics, MTG
  traversal/construction, local mesh creation and PlantGeom materialization.
- [ ] Measure whether node creation or per-day recomputation dominates.
- [ ] Confirm how often each geometry function is called per leaf and per day.
- [ ] Rank hotspots by cumulative time and allocated bytes.

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

### Phase 4 — Reduce topology and traversal costs

- [ ] Measure repeated `descendants`/`traverse!` lookups during updates.
- [ ] Cache safe references or node identifiers for leaf geometry children.
- [ ] Preallocate or bulk-create predictable petiole, rachis and leaflet nodes
  if MultiScaleTreeGraph supports this without breaking identifiers or links.
- [ ] Avoid rebuilding topology when only transformations changed.
- [ ] Keep pruning correct for MTG nodes and any future PlantSimEngine objects.
- [ ] Confirm that optimization does not make standalone `merge_scale` behavior
  inconsistent.

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
- [ ] Test whether families of identical shapes can share `RefMesh` instances;
  do not assume sharing is valid for leaflets with different dimensions.

PlantGeom already represents geometry as a shared `RefMesh` plus a per-node
transformation and materializes lazily. Prefer using that contract fully before
adding a new cache layer.

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
- the 4,160-step release regression currently protects `architecture=false`;
  the exact false/true A/B harness is still an external artifact and should be
  promoted into a short CI test plus a scheduled full test.

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
| 2026-08-30 | Keep the full A/B benchmark in-repository but its generated data outside the tree | the previous driver was an external artifact and could not fully fingerprint the active environment | provide a fixed-seed 21-series runner and retain machine-readable results with each reported run |

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
- [ ] The five-year approximately 120-leaf palm has been checked numerically and
  visually at several dates, not only at the final date.
- [ ] Full coupled physiology remains identical while architecture is an
  observer.
- [ ] Fresh paired benchmarks meet the main performance target or document a
  measured residual bottleneck and justified next step.
- [ ] Any PlantGeom change is independently tested and reviewed in PlantGeom.
- [ ] GPU work is either rejected with measurements or isolated behind a tested
  CPU fallback.
- [ ] Temporary benchmark artifacts are removed or archived outside the source
  tree.
- [ ] This temporary file is removed or converted into permanent documentation
  before the optimization pull request is merged.
