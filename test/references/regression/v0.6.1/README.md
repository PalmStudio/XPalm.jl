# XPalm v0.6.1 numerical reference

These files are the compact regression oracle for the default full-cycle
simulation shown in XPalm's README:

- `trajectory_checkpoints.csv` stores the first day, every first day of a
  calendar month, and the final day at Scene, Plant, and Soil scales;
- `harvest_events.csv` stores every bunch-harvest event and the cumulative
  bunch and oil yields;
- `summary.csv` stores whole-cycle extrema and final cumulative values;
- `metadata.toml` records the exact XPalm tag and commit, PlantSimEngine and
  Julia versions, meteorological-input hash, and stochastic seeds.

The baseline was generated from XPalm `v0.6.1` with PlantSimEngine `v0.14.1`.
It is intentionally small enough to version in Git and should not be
regenerated merely to make a failing test pass.

Run the slow regression explicitly with:

```sh
julia --project=test test/runtests.jl reference-regression
```

Ordinary local tests skip it. CI runs it on one pinned Linux/Julia job. To
update the fixture intentionally, reproduce the released environment first,
review the numerical differences, then run the generator with the overwrite
guard enabled:

```sh
XPALM_UPDATE_REFERENCE=true julia --project=test \
  scripts/generate_reference_regression.jl \
  test/references/regression/v0.6.1
```

Commit a metadata update and a scientific explanation with every accepted
baseline change.
