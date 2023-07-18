"""
BiomassFromArea(lma_min,leaflets_biomass_contribution)
BiomassFromArea(lma_min=  80.0, leaflets_biomass_contribution=0.35)

Compute leaf biomass from leaf area

# Arguments
- `lma_min`: minimal leaf mass area (when there is no reserve in the leaf)
- `leaflets_biomass_contribution`: ratio of leaflets biomass to the  total leaf biomass (including rachis and petiole) ([0,1])

# inputs
- `leaf_area`: leaf area (m2)

# outputs
- `biomass`: leaf biomass (g)
"""
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



"""
LeafBiomass(respiration_cost)
LeafBiomass(respiration_cost=1.44)

Compute leaf biomass from carbon_allocation

# Arguments
- `respiration_cost`: respiration cost of the leaf (g.g-1)

# inputs
- `carbon_allocation`: carbon allocated to the leaf (g)

# outputs
- `biomass`: leaf biomass (g)
"""
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

    status.biomass = MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do leaf
        leaf[:models].status[rownumber(status)][:biomass]
    end |> sum
end