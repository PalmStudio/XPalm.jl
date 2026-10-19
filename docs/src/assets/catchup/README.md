# Archived scientific figures for the XPalm pull-request discussion

These are the user-requested conference figures and compact data selections, staged on 19 October 2026. No Julia process, simulation, calibration, or figure rendering was run while staging them. PNG files and archived Julia sources are byte-for-byte copies; the SHA-256 index records their sources. CSV selections retain the saved numeric text and do not recompute results.

## Contents and interpretation

- `organ/`: the red-observation single-bunch figure. The two upper panels use each run's own demand and allocation, with independent y scales; orange indicates carbon allocation deficit. The lower growth excludes external endpoint correction. Its compact data omit tree/UID fields and use days before harvest. This was a selected illustrative bunch, not a representative sample.
- `annual_fruit/`: the standalone fruit dry-mass panel with red observed points.
- `annual_cohorts/`: the archived three-panel fruit/stalk/cumulative-correction figure and its compact plotted tables. The annual values cover the same 50 measured PR cohorts in 2014–2022, not exhaustive annual palm or plantation yield. The cumulative table omits source UID fields. The archived figure has black observation markers; the standalone fruit version uses red.
- `historical_whole_model/`: the historical three-model, three-site figure with annual FFB, bunch count and fresh bunch mass. It compares previous calibrated, revised unrecalibrated and revised recalibrated *bundles*, with several concurrent changes and different historical fitting objectives. The blue model is not an untouched XPalm release. The retained tables include exactly the plotted calendar-year/all-progenies response summaries and aggregate observation P10/P90 values. Pooled FFB metrics use equal observed site-year weights and the three-seed mean, not averages of site-specific scores.
- `controlled_comparison/`: the newer C/D/E comparison under a common calibration protocol. C is the calibrated production-onset bundle, D adds native-target catch-up/earlier stalk scheduling at the same parameters, and E recalibrates D. This countercheck does not show universal improved prediction: training FFB improves slightly, but later pooled FFB RMSE changes from 84.63 (C) to 83.07 (D) to 87.34 (E) kg fresh/palm/year.
- `sources/`: exact archived Julia/CairoMakie figure generators retained for provenance, plus the new portable plotting-only driver `render_public_figures.jl`.

The conditional PR example fixes observed targets and dates, uses a retrospective ordinal organ-mapping assumption and retains a signed external endpoint-adjustment ledger. Curves are evaluated *before* external harvest correction. Recovery has no separately calibrated maximum rate in this experiment or the new default formulation. Conditional target recovery is not independent predictive validation.

The whole-model figures are unforced with no external biomass adjustment. FFB uses provisional fixed fruit/stalk water fractions 0.2358/0.667. Both early-year calibrations include Towé. Years 2019–2022 had already been inspected during development and constitute temporal evaluation, not untouched validation. Bands describe the range of three stochastic seeds, not confidence intervals or population uncertainty.

## Historical experiments versus the current package port

The copied figures come from archived application experiments run with XPalm0.7.0/PlantSimEngine0.15.0 and local model alternatives. They were not regenerated from the current XPalm package implementation. They explain the hypothesis and diagnostic history; they do not prove numerical equivalence of the port or isolated effects of every PR change. Package regression tests and any new runs must be reported separately. Archived checks establish the recorded historical figure/input checks only.

## Reproduction dependencies

Underlying private project: `/Users/rvezy/Documents/dev/XPalm_calibration_new`. Presentation source: `/Users/rvezy/Documents/cirad/Articles_Rapports_Communications/Conférences/2026_fspm/vezy_digital_twins/presentation`. All Julia executions must be started/controlled through Kaimon, using the appropriate pinned environment.

The two exact copied sources deliberately keep their original file dependencies and checks. Those archival files are **not standalone scripts that can execute against these reduced public CSVs**:

- `single_bunch_hypotheses.jl` expects the original `figures/individual_bunch_trajectories.csv`, including private identity/check columns removed here. Its relative input location refers to the original source directory.
- `annual_fruit_panel_red.jl` expects archived `reference/cohorts.csv`, `catchup/cohorts.csv`, experiment checks and `src/presentation_panels.jl` in the private project. Those cohort files are not redistributed.
- The archived three-panel figure can be reproduced from application scripts84–86; the historical full-model comparison from script96, with pooled FFB metrics from99; the controlled sequence from101–104. Exact model and parameter archives remain in the project.

### Portable reproduction of figure drawing

The new `sources/render_public_figures.jl` is a separate plotting-only driver. It reads the shipped `organ/plotted_values.csv` and `annual_fruit/plotted_values.csv` directly, plus the observed endpoint annotation in `organ/archived_figure_checks.toml`. It has no private filesystem dependency and does not load XPalm or any simulation/calibration code. Its Julia dependencies are CSV, DataFrames and CairoMakie; Printf, SHA and TOML are standard libraries.

Through a Kaimon-controlled Julia session with those dependencies available:

```julia
include("path/to/this/evidence/sources/render_public_figures.jl")
XPalmPublicFigureRenderer.render_all()
```

This exports the organ figure with and without its lower green curve, and the standalone annual fruit figure, in PNG, SVG and PDF. By default, new files go to `regenerated_public/`, preserving the exact archived exports. The two organ frames retain the same axes, complete legends and red observation marker. Daily carbon deficit is shown separately for each run, with independent upper-panel y scales. The annual figure retains the original crop's labels and no extra legend; grey is fixed schedule, green is catch-up, and red points are the observed mass targets.

The driver checks aligned daily trajectories, finite demands and allocations, monotonic fruit growth, recorded endpoints, deficit-day counts, matching annual targets and cohort counts, and input-file hashes. `DRAWING_CHECKS.toml` records those drawing/data checks and new output hashes. It does **not** claim a new scientific simulation or a pixel-identical rendering: fonts and CairoMakie versions can affect appearance. The portable renderer was authored separately from the untouched archival generators; execution and visual checks must be reported separately by the PR task.

Reproducing these drawings is distinct from rerunning the private experiment or calibration. No raw database, per-palm source identifier, raw per-tree record table, or full daily model archive is included.

`SHA256_INDEX.json` is the staged-file manifest. It distinguishes exact copies from column/row selections and records the source hash, output hash and selection metadata. Its hashes are fresh staging checks, not newly executed scientific tests.
