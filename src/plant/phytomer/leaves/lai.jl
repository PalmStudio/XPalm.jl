"""
LAIModel()

Compute the leaf area index (LAI) using all leaves in the scene and the scene surface area.

# Arguments

- `area`: the surface area of the scene.

# Inputs

- `leaf_area`: a vector of all leaf area values in the scene

# Outputs

- `lai`: the leaf area index (m² m⁻²)
"""
struct LAIModel{T} <: AbstractLai_DynamicModel
    area::T
end

PlantSimEngine.inputs_(::LAIModel) = (leaf_area=[-Inf],)
PlantSimEngine.outputs_(::LAIModel) = (lai=-Inf, scene_leaf_area=-Inf)

# Applied at the scene scale:
function PlantSimEngine.run!(m::LAIModel, models, st, meteo, constants, extra=nothing)
    st.scene_leaf_area = sum(st.leaf_area)
    st.lai = st.scene_leaf_area / m.area # m2 leaf / m2 soil
end
