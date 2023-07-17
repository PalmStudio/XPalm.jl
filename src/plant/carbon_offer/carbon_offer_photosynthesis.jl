"""
    CarbonOfferPhotosynthesis()

A model that computes carbon offer as the `carbon_assimilation`.


"""
struct CarbonOfferPhotosynthesis <: AbstractCarbon_OfferModel end

PlantSimEngine.inputs_(::CarbonOfferPhotosynthesis) = (carbon_assimilation=-Inf,)
PlantSimEngine.outputs_(::CarbonOfferPhotosynthesis) = (carbon_offer=-Inf,)

# Should be applied at the plant scale:
function PlantSimEngine.run!(::CarbonOfferPhotosynthesis, models, status, meteo, constants, extra=nothing)
    status.carbon_offer = status.carbon_assimilation
end
