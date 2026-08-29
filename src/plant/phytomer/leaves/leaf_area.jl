"""
    LeafAreaModel(lma_min, leaflets_biomass_contribution, leaf_area_ini, carbon_concentration)

Leaf area from its biomass.

# Arguments

- `lma_min`: minimal leaflet dry mass per unit leaflet area (gDM m⁻²,
  when there is no reserve in the leaf)
- `leaflets_biomass_contribution`: ratio of leaflets biomass to total leaf biomass including rachis and petiole (0-1)
- `carbon_concentration`: leaf carbon concentration (gC gDM⁻¹)

# Inputs

- `biomass`: total leaf biomass, including leaflets, rachis and petiole (gC)

# Outputs

- `leaf_area`: leaf area (m2)
"""
struct LeafAreaModel{T} <: AbstractLeaf_AreaModel
    lma_min::T
    leaflets_biomass_contribution::T
    leaf_area_ini::T
    carbon_concentration::T
end

# Compatibility with the historical three-argument constructor. The LMA is a
# dry-mass quantity, whereas `biomass` is carbon biomass.
LeafAreaModel(lma_min, leaflets_biomass_contribution, leaf_area_ini) =
    LeafAreaModel(lma_min, leaflets_biomass_contribution, leaf_area_ini, 0.48)

PlantSimEngine.inputs_(::LeafAreaModel) = (
    biomass=PlantSimEngine.Required(Real),
)
PlantSimEngine.outputs_(m::LeafAreaModel) = (leaf_area=m.leaf_area_ini,)

# Applied at the phytomer scale:
function PlantSimEngine.run!(m::LeafAreaModel, status, environment, constants, context=nothing)
    status.leaf_area = status.biomass * m.leaflets_biomass_contribution /
                       (m.lma_min * m.carbon_concentration)
end


"""
    PlantLeafAreaModel()

Sum of the leaf area at plant scale.

# Inputs

- `leaf_area_leaves`: a vector of leaf area (m²)
- `leaf_states`: a vector of leaf states. Only leaves with state :opened are considered.

# Outputs

- `leaf_area`: total leaf area of the plant (m²)
"""
struct PlantLeafAreaModel <: AbstractLeaf_AreaModel end

PlantSimEngine.inputs_(::PlantLeafAreaModel) = (
    leaf_area_leaves=PlantSimEngine.Required(AbstractVector),
    leaf_states=PlantSimEngine.Required(AbstractVector),
)
PlantSimEngine.outputs_(::PlantLeafAreaModel) = (leaf_area=-Inf,)

# Applied at the plant / scene scale:
function PlantSimEngine.run!(m::PlantLeafAreaModel, st, environment, constants, context=nothing)
    st.leaf_area = sum(st.leaf_area_leaves[st.leaf_states.==:opened])
end
