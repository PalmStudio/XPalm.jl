# XPalm

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/XPalm.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/XPalm.jl/dev/)
[![Build Status](https://github.com/PalmStudio/XPalm.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/XPalm.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/XPalm.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/PalmStudio/XPalm.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

# Roadmap

- Manage the case when photosynthesis + reserves are not enough for maintenance respiration: e.g. abortions ? 
- Add variable than tells us how far we are from the demand, i.e. (demand - allocation)
- Each MTG Node has its ModelList with its models and parameters. The model has potentially a different method for the scale it is computed at, e.g. carbon_demand is different for a leaf than a fruit, and for the palm (in this case it just sums-up all demands). Even we can have a method that does nothing (e.g. for a snag, no carbon_demand)
- See if we add the variables at palm scale inside the organs Status, as a pointer to its own status, e.g. for computing the sex ratio, we for example need the IC_sex common for the whole plant (as a value in the status, shared between all organs and pointing to the value in the Palm scale)
- remove dependency to dev versions of packages
- LAIModel: traverse the MTG for all plants but stop at the plant scale (do not traverse every node)
- Test difference between LeafCarbonDemandModelArea and LeafCarbonDemandModelPotentialArea. The first assumes that the leaf can always increase its demand more than the potential to catch back any delay in growth induced by previous stress. The second assumes that the potential daily increment only follows the daily potential curve, and that any lost demand induced by stress will be lost demand.
- For LAI, only use the leaf area of the leaves that are `Opened()`.
- For models that specialize on the organ type, we should probably just make one model for each organ type (or at least for each that needs a different algorithm).
- Initialisations should maybe be given in the model structure and done in the model itself ? See `src/plant/reserves/reserve_filing_leaf_and_stem.jl` for example, where we check if the value of the previous day is == -Inf and take the current value if so because the initialization is done on the current day, and the previous date is at -Inf. Or simply initialize the day previous organ initiation so the code is the same whatever the time step.

To add: maintenance respiration, affect LAI from surface and biomass of the leaves, and thus affect the carbon_demand of the plant, and the carbon_supply of the plant.

Add reserves for leaves.
