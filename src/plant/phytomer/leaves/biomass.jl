struct BiomassFromArea{T} <: AbstractBiomass_From_AreaModel
    lma_min::T
    leaflets_biomass_contribution::T
end

PlantSimEngine.inputs_(::BiomassFromArea) = (leaf_area=-Inf,)
PlantSimEngine.outputs_(::BiomassFromArea) = (biomass=-Inf,)

# Applied at the leaf scale:
function PlantSimEngine.run!(m::BiomassFromArea, models, st, meteo, constants, extra=nothing)
    st.biomass = st.leaf_area * m.lma_min / m.leaflets_biomass_contribution
end

# Used after init:
struct LeafBiomass{T} <: AbstractBiomassModel
    respiration_cost::T
end

PlantSimEngine.inputs_(::LeafBiomass) = (carbon_allocation=-Inf,)
PlantSimEngine.outputs_(::LeafBiomass) = (biomass=-Inf,)

# Applied at the leaf scale:
function PlantSimEngine.run!(m::LeafBiomass, models, st, meteo, constants, extra=nothing)
    st.biomass =
        prev_value(st, :biomass, default=st.biomass) +
        st.carbon_allocation / m.respiration_cost
end

# Plant scale:
function PlantSimEngine.run!(::LeafBiomass, models, status, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    @assert mtg.MTG.symbol == "Plant" "The node should be a Plant but is a $(mtg.MTG.symbol)"
    biomass = Vector{typeof(status.biomass)}()

    MultiScaleTreeGraph.traverse!(mtg, symbol="Leaf") do leaf
        push!(biomass, leaf[:models].status[rownumber(status)][:biomass])
    end

    status.biomass = sum(biomass)
end