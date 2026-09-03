"""
    CarbonOfferRm()

A model that computes carbon offer as the carbon assimilation minus the 
maintenance respiration.

All three fluxes are daily g CH2O-equivalent values. Alternative
photosynthesis models must convert their output to this currency before this
model boundary.
"""
struct CarbonOfferRm <: AbstractCarbon_OfferModel end

PlantSimEngine.inputs_(::CarbonOfferRm) = (
    carbon_assimilation=PlantSimEngine.Required(Real),
    Rm=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(::CarbonOfferRm) = (carbon_offer_after_rm=-Inf,)
PlantSimEngine.variable_contracts_(::CarbonOfferRm) = (
    carbon_assimilation=_DAILY_CH2O_EQUIVALENT_FLOW,
    Rm=_DAILY_CH2O_EQUIVALENT_FLOW,
    carbon_offer_after_rm=_DAILY_CH2O_EQUIVALENT_FLOW,
)

# Should be applied at the plant scale:
function PlantSimEngine.run!(::CarbonOfferRm, status, environment, constants, context=nothing)
    status.carbon_offer_after_rm = max(status.carbon_assimilation - status.Rm, 0.0)
end
