# XPalm unit convention:
# - `carbon_*`, `reserve`, and maintenance-respiration flows use
#   carbohydrate-equivalent mass (g CH2O-equivalent);
# - organ `biomass*` variables use structural dry mass (gDM); reserves remain
#   separate carbohydrate-equivalent pools;
# - construction costs convert gDM growth into g CH2O-equivalent demand and
#   back.
@process "carbon_assimilation" verbose = false
@process "carbon_demand" verbose = false
@process "carbon_offer" verbose = false
@process "carbon_allocation" verbose = false
@process "biomass" verbose = false
@process "state" verbose = false
@process "potential_evapotranspiration" verbose = false
@process "thermal_time" verbose = false
