# XPalm numerical regression references

On the reproductive-lifecycle development branch, CI compares the default
4,160-day simulation with the separately named `v0.7.0-lifecycle-dev` candidate.
Its intentional changes and source fingerprints are reviewed with the PR;
it is not a new release or an empirical validation.

- [`v0.7.0-lifecycle-dev`](v0.7.0-lifecycle-dev/README.md) is the unreleased
  lifecycle/rooted-recharge candidate used by this branch.
- [`v0.7.0`](v0.7.0/README.md) remains the immutable released reference. Its numerical data
  were promoted unchanged from the reviewed `v0.7.0-dev` candidate.
- [`v0.6.1`](v0.6.1/README.md) is the immutable released oracle retained for
  provenance and historical comparisons.

Continuous quantities use tight approximate comparisons (`rtol = atol =
1e-8`). Dates, timesteps, event counts, and cumulative organ counts remain
exact comparisons. A baseline update therefore requires a scientific review;
loosening tolerances or overwriting a released oracle is not an acceptable way
to make CI pass.
