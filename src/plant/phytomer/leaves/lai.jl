struct LAIModel <: AbstractLai_DynamicModel end

PlantSimEngine.inputs_(::LAIModel) = (leaf_area=-Inf,)
PlantSimEngine.outputs_(::LAIModel) = (lai=-Inf,)

# Applied at the scene scale:
function PlantSimEngine.run!(::LAIModel, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    leaf_area = typeof(st.leaf_area)[]
    MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do leaf
        # if leaf.type.state == Opened()
        push!(leaf_area, leaf[:models].status[rownumber(st)][:leaf_area])
        # end
    end
    st.lai = sum(leaf_area) / mtg[:area] # m2 leaf / m2 soil
end

# Propagate the value from the day before:
function PlantSimEngine.run!(::LAIModel, models, st, meteo, constants, extra=nothing)
    st.lai = prev_value(st, :lai, default=st.lai)
end
