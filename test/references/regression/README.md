# XPalm numerical regression references

The CI regression compares the default 4,160-day simulation with the
`v0.7.0-dev` candidate baseline. This is the accepted development behavior
intended for XPalm v0.7.0 after the post-v0.6.1 carbon-unit and respiration
corrections.

- [`v0.7.0-dev`](v0.7.0-dev/README.md) is the active CI oracle and candidate
  for the future v0.7.0 release.
- [`v0.6.1`](v0.6.1/README.md) is the immutable released oracle retained for
  provenance and historical comparisons.

Continuous quantities use tight approximate comparisons (`rtol = atol =
1e-8`). Dates, timesteps, event counts, and cumulative organ counts remain
exact comparisons. A baseline update therefore requires a scientific review;
loosening tolerances or overwriting a released oracle is not an acceptable way
to make CI pass.
