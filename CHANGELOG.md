# Changelog

## Unreleased

### Changed

- Updated the full-cycle numerical regression baseline after the intentional
  leaf-carbon, organ dry-mass, CH2O-equivalent carbon-currency, and respiration
  corrections. The released v0.6.1 baseline remains available as an immutable
  historical reference.

### Breaking changes

- XPalm now requires PlantSimEngine 0.15 and executes hard dependencies
  directly through `run_call!(RunContext, Symbol)`.
- Removed the internal package-local hard-call compatibility helper and legacy
  direct-kernel fallback. FTSW, FTSW_BP, and phytomer hard-call models must run
  in a compiled `CompositeModel`.
