# XPalm

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PalmStudio.github.io/XPalm.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PalmStudio.github.io/XPalm.jl/dev/)
[![Build Status](https://github.com/PalmStudio/XPalm.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/PalmStudio/XPalm.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/PalmStudio/XPalm.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/PalmStudio/XPalm.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

# Add a model

To add a new model and process, you need to:

- define the process in a `0-process.jl` file using `@process`
- define a model that implement the process. If the computation needs values from other organs, you can use the mtg as the last argument of the `run!` function. 
- add the model in the ModelList of the organ(s) you want it to simulate. If the output of the model needs to be passed to other organs, you can write a specific implementation for the organ type for the `run!` function (see carbon allocation for example)
- If the model needs parameters, add the parameters in the parameter dictionnary in `structs.jl`, in the `default_parameters()` function around l.140.
- Add a call to the model in `run_XPalm()` in the `run.jl` script. The model should be called at the right moment in the script considering its dependencies over previously computed variables. It can also take the mtg node of an organ as last argument, or `nothing` if the mtg is not needed. Make sure to call the right method, as sometimes a model has a different method when called with an MTG node.
- Run the `run_XPalm.jl` file in the examples scripts, and make sure that everything runs. If there is an error, make sure to read the lines of the error that correspond to the `XPalm` package, not the others, as the error most probably comes from your new implementation rather than another package.



# To do

- Manage the case when photosynthesis + reserves are not enough for maintenance respiration: e.g. abortions ? 
- Add variable than tells us how far we are from the demand, i.e. (demand - allocation)
- Each MTG Node has its ModelList with its models and parameters. The model has potentially a different method for the scale it is computed at, e.g. carbon_demand is different for a leaf than a fruit, and for the palm (in this case it just sums-up all demands). Even we can have a method that does nothing (e.g. for a snag, no carbon_demand)
- See if we add the variables at palm scale inside the organs Status, as a pointer to its own status, e.g. for computing the sex ratio, we for example need the IC_sex common for the whole plant (as a value in the status, shared between all organs and pointing to the value in the Palm scale)
- remove dependency to dev versions of packages
- LAIModel: traverse the MTG for all plants but stop at the plant scale (do not traverse every node)
- Test difference between LeafCarbonDemandModelArea and LeafCarbonDemandModelPotentialArea. The first assumes that the leaf can always increase its demand more than the potential to catch back any delay in growth induced by previous stress. The second assumes that the potential daily increment only follows the daily potential curve, and that any lost demand induced by stress will be lost demand.
- For models that specialize on the organ type, we should probably just make one model for each organ type (or at least for each that needs a different algorithm).
- Initialisations should maybe be given in the model structure and done in the model itself ? See `src/plant/reserves/reserve_filing_leaf_and_stem.jl` for example, where we check if the value of the previous day is == -Inf and take the current value if so because the initialization is done on the current day, and the previous date is at -Inf. Or simply initialize the day previous organ initiation so the code is the same whatever the time step.
- There can still be some carbon offer at the end of the day, where do we put it ? 
- Increase the new internode size when the reserves are full ?
- Check the carbon balance (add it as a variable?)
- Add maintenance respiration
- Affect LAI from surface and biomass of the leaves, and thus affect the carbon_demand of the plant, and the carbon_supply of the plant.
- Test if it is faster to pass the models as the first argument (*e.g.* `m.param`) or to use the models argument *e.g.* `models.maintenance_respiration.param` 
- in add_phytomer: determine inputs, outputs and model dependency
- in carbon allocation, put again `reserve` as needed input. We had to remove it because PSE detects a cyclic dependency with reserve filling. This is ok to remove because carbon allocation needs the value from the day before. We should define how this is done in PSE, e.g. via a special type that provides the values from the day before or else ? Maybe more a way to say to the model that we take the value from before, in the modellist directly e.g. `carbon_allocation = [:reserve => PreviousTimeStep(1)] => CarbonAllocationModel()`
- Add model dependency in sex determination
