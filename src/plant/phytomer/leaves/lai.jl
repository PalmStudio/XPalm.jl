struct LAIModel <: AbstractLai_DynamicModel end

PlantSimEngine.inputs_(::LAIModel) = (leaf_area=-Inf,)
PlantSimEngine.outputs_(::LAIModel) = (lai=-Inf,)

# Applied at the scene scale:
function PlantSimEngine.run!(::LAIModel, models, st, meteo, constants, mtg::MultiScaleTreeGraph.Node)
    leaf_area = MultiScaleTreeGraph.traverse(mtg, symbol="Leaf") do node
        node[:models].status[PlantMeteo.rownumber(st)][:leaf_area]
    end
    plant_density = MultiScaleTreeGraph.ancestors(mtg, :plant_density, symbol="Scene")[1]
    st.lai = sum(leaf_area) * (plant_density / 10000)
end