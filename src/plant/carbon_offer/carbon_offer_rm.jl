"""
    CarbonOfferRm()

A model that computes carbon offer as the carbon assimilation minus the 
maintenance respiration.
"""
struct CarbonOfferRm <: AbstractCarbon_OfferModel end

PlantSimEngine.inputs_(::CarbonOfferRm) = (carbon_assimilation=-Inf, Rm=-Inf)
PlantSimEngine.outputs_(::CarbonOfferRm) = (carbon_offer_after_rm=-Inf,)

# Should be applied at the plant scale:
function PlantSimEngine.run!(::CarbonOfferRm, models, status, meteo, constants, extra=nothing)
    status.carbon_offer_after_rm = status.carbon_assimilation - status.Rm
end
