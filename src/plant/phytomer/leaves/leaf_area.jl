"""
    LeafAreaModel(lma_min, leaflets_biomass_contribution, leaf_area_ini)

Leaf area from its biomass.

# Arguments

- `lma_min`: minimal leaf mass area (when there is no reserve in the leaf)
- `leaflets_biomass_contribution`: ratio of leaflets biomass to total leaf biomass including rachis and petiole (0-1)

# Inputs

- `biomass`: leaf biomass (g)

# Outputs

- `leaf_area`: leaf area (m2)
"""
struct LeafAreaModel{T} <: AbstractLeaf_AreaModel
    lma_min::T
    leaflets_biomass_contribution::T
    leaf_area_ini::T
end

PlantSimEngine.inputs_(::LeafAreaModel) = (biomass=0.0,)
PlantSimEngine.outputs_(m::LeafAreaModel) = (leaf_area=m.leaf_area_ini,)

# Applied at the phytomer scale:
function PlantSimEngine.run!(m::LeafAreaModel, models, status, meteo, constants, extra=nothing)
    status.leaf_area = status.biomass * m.leaflets_biomass_contribution / m.lma_min
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

PlantSimEngine.inputs_(::PlantLeafAreaModel) = (leaf_area_leaves=[-Inf], leaf_states=[:undetermined])
PlantSimEngine.outputs_(::PlantLeafAreaModel) = (leaf_area=-Inf,)

# Applied at the plant / scene scale:
function PlantSimEngine.run!(m::PlantLeafAreaModel, models, st, meteo, constants, extra=nothing)
    st.leaf_area = sum(st.leaf_area_leaves[st.leaf_states.==:opened])
end