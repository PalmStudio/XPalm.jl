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