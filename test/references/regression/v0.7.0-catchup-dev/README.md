# Unreleased bunch-growth numerical reference

This candidate records the default simulation after replacing fixed daily female
carbon demand with demand for scheduled but unfinished growth. It includes the
preceding lifecycle and rooted-recharge fixes. No opt-in flag or fitted parameter
is used: the scenario calls `XPalm.default_parameters()`.

The previous `v0.7.0-lifecycle-dev` candidate and the released `v0.7.0` reference
remain unchanged. Compare the three candidates to separate the demand change
from the earlier fixes. This is a numerical regression scenario, not a field
calibration or validation.

The complete 4,160-day weather sequence, architecture setting and default random
seeds are unchanged. Metadata records exact model-source fingerprints and input
hashes. Continuous checks retain `rtol = atol = 1e-8`; dates, counts and events
are compared exactly. The tests also protect released-file checksums and check
daily stocks, cumulative yield and harvest pulses.

Regenerate using `scripts/generate_reference_regression.jl` in a Kaimon-controlled
Julia process resolving XPalm to this checkout. Updating an existing candidate
requires `XPALM_UPDATE_REFERENCE=true`. Released references cannot be overwritten.
Review numerical changes before accepting a regenerated candidate.

## Change from the lifecycle-only reference

The default scenario retains 344 phytomers and 220 fruit-bearing harvest events.
Cumulative bunch dry mass changes from 513.485 to 512.984 kg (−0.10%), and final
LAI remains 6.0053. These small coupled numerical differences are recorded rather
than assumed away. This scenario is a regression check with standard parameters;
the observation-conditioned CIGE experiments in the model note address a
different question and use their archived parameter sets.
