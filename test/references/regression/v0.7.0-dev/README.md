# XPalm v0.7.0-dev numerical reference

These files are the active compact regression oracle and candidate baseline
for the future XPalm v0.7.0 release. They were generated on Julia 1.12.1 from
the XPalm model at commit `d4ded8891d03f85bb5691b89572a4e003ac6eb7a` with
PlantSimEngine 0.15.0 at commit
`82786fba91fad644d8068d75afc64d88282400c4`.
The metadata hashes the committed `test/Project.toml`; ignored local manifests
are deliberately excluded from the provenance record.

This baseline follows intentional post-v0.6.1 scientific corrections to leaf
biomass carbon units, organ dry-mass bookkeeping, the CH2O-equivalent carbon
currency, and respiration calibration. The released
[`v0.6.1`](../v0.6.1/README.md) files remain unchanged as the historical
oracle.

The reviewed whole-cycle changes from v0.6.1 are:

| Quantity | v0.6.1 | v0.7.0-dev | Change |
| --- | ---: | ---: | ---: |
| Harvested bunches | 128 | 118 | -10 |
| Total bunch yield (gDM) | 336683.0948 | 289035.1660 | -14.15% |
| Total oil yield (gDM) | 62061.1368 | 52399.5645 | -15.57% |
| Final LAI | 5.058760 | 5.208506 | +2.96% |
| Maximum LAI | 5.673506 | 6.276242 | +10.62% |

The final phytomer count remains exactly 344. The new values are deterministic
across repeated warmed runs, so the differences are model changes rather than
Ubuntu floating-point noise.

Run the regression explicitly with:

```sh
julia --project=test test/runtests.jl reference-regression
```

Ordinary local tests skip it. CI runs it on one pinned Linux/Julia job. To
replace this v0.7.0 development fixture intentionally, review the numerical
differences first, then run the generator with the overwrite guard enabled:

```sh
XPALM_UPDATE_REFERENCE=true XPALM_REFERENCE_RELEASE_STATE=unreleased \
  julia --project=test \
  scripts/generate_reference_regression.jl \
  test/references/regression/v0.7.0-dev
```

Record the scientific rationale and exact dependency revisions with every
accepted update. When v0.7.0 is released, rename the baseline to `v0.7.0` and
record it with `release_state = "released"`.
