"""
LAIModel()

Compute the leaf area index (LAI) using all leaves in the scene and the scene surface area.

# Arguments

- `area`: the surface area of the scene.

# Inputs

- `leaf_areas`: a vector of all leaf area values in the scene (from each leaf, or each plant)

# Outputs

- `leaf_area`: the total leaf area of the scene (m²)
- `lai`: the leaf area index (m² m⁻²)

"""
struct LAIModel{T} <: AbstractLai_DynamicModel
    area::T
end

PlantSimEngine.inputs_(::LAIModel) = (leaf_areas=[-Inf],)
PlantSimEngine.outputs_(::LAIModel) = (lai=-Inf, leaf_area=-Inf)

# Applied at the scene scale:
function PlantSimEngine.run!(m::LAIModel, models, st, meteo, constants, extra=nothing)
    st.leaf_area = sum(st.leaf_areas)
    st.lai = st.leaf_area / m.area # m2 leaf / m2 soil
end
