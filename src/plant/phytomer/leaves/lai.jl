struct LAIModel <: AbstractLai_DynamicModel end

PlantSimEngine.inputs_(::LAIModel) = (leaf_area=-Inf,)
PlantSimEngine.outputs_(::LAIModel) = (lai=-Inf,)

# Applied at the scene scale:
function PlantSimEngine.run!(::LAIModel, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    leaf_area = MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do node
        node[:models].status[PlantMeteo.rownumber(st)][:leaf_area]
    end
    st.lai = sum(leaf_area) * (mtg[:plant_density][1] / 10000)
end