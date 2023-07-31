"""
LAIModel()

Compute LAI from every leaf area of the MTG

# Arguments

# inputs

- `leaf_area`: leaf area of each leaf
-`mtg`: MultiScaleTreeGraph of a scene with a ground area

# outputs
- `lai`: leaf area index (m2.m-2)
"""


struct LAIModel <: AbstractLai_DynamicModel end

PlantSimEngine.inputs_(::LAIModel) = (leaf_area=-Inf,)
PlantSimEngine.outputs_(::LAIModel) = (lai=-Inf,)

# Applied at the scene scale:
function PlantSimEngine.run!(::LAIModel, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    leaf_area = typeof(st.leaf_area)[]
    MultiScaleTreeGraph.traverse!(mtg, symbol="Leaf") do leaf
        # if leaf[:models].status[rownumber(st)][:leaf_state] == "Opened"
        push!(leaf_area, leaf[:models].status[rownumber(st)][:leaf_area])
        # end
    end
    st.lai = sum(leaf_area) / mtg[:area] # m2 leaf / m2 soil
end

# Propagate the value from the day before:
function PlantSimEngine.run!(::LAIModel, models, st, meteo, constants, extra=nothing)
    st.lai = prev_value(st, :lai, default=st.lai)
end
