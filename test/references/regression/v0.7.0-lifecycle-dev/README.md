# Unreleased lifecycle and rooted-recharge numerical candidate

This is a separately named, **unreleased** numerical candidate for the lifecycle
and BP rooted-recharge corrections. It is not a replacement or relabeling of the
released `v0.7.0` oracle. Every file in that released directory is retained byte
for byte, with fixed SHA-256 checks in the regression test.

The intended scientific changes are:

- Rank pruning removes a leaf without prematurely harvesting its inflorescence.
- An abortion decision made during phenology remains terminal in that timestep.
- Harvest mass and fruit-count outputs are one-timestep pulses.
- Effective rainfall recharges the overlapping rooted BP water view after the
  bulk view has been updated.

These changes can alter water stress, vegetative feedbacks, reproductive survival,
harvest dates and cumulative yield. This candidate must therefore be reviewed
against `../v0.7.0/`, rather than asserted to reproduce released trajectories.
No physiological parameter recalibration, natural-senescence law, revised
reproductive clock or growth-recovery hypothesis is included in this candidate.

The scenario is unchanged: the complete 4,160-day `0-data/meteo.csv`, the default
parameter dictionary and its recorded sex/abortion seeds, with architecture
disabled. The generator records the model source commit, per-source SHA-256
fingerprints, environment, weather hash and hashes of all three numerical CSVs.
The commit alone may precede local modifications: the per-source fingerprints
identify the exact source used to generate this candidate.

The full-cycle test retains the original strict numerical comparison: continuous
values use `rtol = atol = 1e-8`; dates, timesteps, event counts and cumulative
organ counts are compared exactly. Daily finite/nonnegative stocks, monotonic
cumulative yield, yield-pulse sums and count-pulse sums remain checked.

## Generate and review

All Julia execution must be controlled through a Kaimon session for this exact
checkout/environment. After confirming `pkgdir(XPalm)` resolves to this checkout:

```julia
include(joinpath(pkgdir(XPalm), "scripts", "generate_reference_regression.jl"))
candidate = joinpath(pkgdir(XPalm), "test", "references", "regression",
    REFERENCE_REGRESSION_CANDIDATE_BASELINE)
reference_candidate = write_reference_regression(candidate; release_state="unreleased")
```

The generator refuses an existing candidate unless `XPALM_UPDATE_REFERENCE=true`
is explicitly set for an intentional update, and refuses overwriting existing
released references even with that flag. Review the generated CSVs and metadata
before committing. In the same exact session, run the reference helper and test
using the package's `test/runtests.jl reference-regression` entry point, or include
`test/test-reference-regression.jl` after loading its declared dependencies and
the helper. Numerical agreement with this candidate is implementation regression
evidence; it is not biological validation of the model changes.
