# struct LeafReserve <: AbstractPotentialReserveModel
#     lma_min
#     lma_max
#     leaflets_biomass_contribution
# end

# PlantSimEngine.inputs_(::LeafReserve) = (leaf_area=-Inf,)
# PlantSimEngine.outputs_(::LeafReserve) = (reserve=-Inf,)

# # Applied at the leaf scale:
# function PlantSimEngine.run!(m::LeafReserve, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)

# end