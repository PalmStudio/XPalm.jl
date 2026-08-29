# XPalm unit contract:
# - `carbon_*`, `reserve`, and maintenance-respiration flows use the plant
#   carbon-equivalent currency (gC-equivalent);
# - organ `biomass*` variables use structural dry mass (gDM); reserves remain
#   separate carbon pools;
# - construction costs convert gDM growth into gC-equivalent demand and back.
@process "carbon_assimilation" verbose = false
@process "carbon_demand" verbose = false
@process "carbon_offer" verbose = false
@process "carbon_allocation" verbose = false
@process "biomass" verbose = false
@process "state" verbose = false
@process "potential_evapotranspiration" verbose = false
@process "thermal_time" verbose = false
