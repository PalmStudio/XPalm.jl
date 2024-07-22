struct ReproductiveOrganEmission <: AbstractReproductive_Organ_EmissionModel
    phytomer_count_init::Int
    graph_node_count_init::Int
    phytomer_symbol::String
end

function ReproductiveOrganEmission(mtg::MultiScaleTreeGraph.Node; phytomer_symbol="Phytomer")
    phytomers = MultiScaleTreeGraph.descendants(mtg, symbol=phytomer_symbol, self=true)
    ReproductiveOrganEmission(length(phytomers), length(mtg), phytomer_symbol)
end

PlantSimEngine.inputs_(m::ReproductiveOrganEmission) = (
    graph_node_count=m.graph_node_count_init, # Also modified in the model, but can't be an output, other models have it too
    phytomer_count=m.phytomer_count_init,
)

PlantSimEngine.outputs_(::ReproductiveOrganEmission) = NamedTuple()
PlantSimEngine.dep(::ReproductiveOrganEmission) = (
    initiation_age=AbstractInitiation_AgeModel,
    final_potential_biomass=AbstractFinal_Potential_BiomassModel,
)
"""
    add_reproductive_organ!(...)

Add a new reproductive organ to a phytomer.
"""
function PlantSimEngine.run!(::ReproductiveOrganEmission, models, status, meteo, constants, sim_object)
    @assert symbol(status.node) == "Phytomer" "The function should be applied to a Phytomer, but is applied to a $(symbol(status.node))"

    status.graph_node_count += 1

    # Create the new organ as a child of the phytomer:
    st_repro_organ = add_organ!(
        status.node[1], # The phytomer's internode is its first child 
        sim_object,  # The simulation object, so we can add the new status 
        "+", status.sex, 4;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}()
    )

    # Compute the initiation age of the organ:
    PlantSimEngine.run!(sim_object.models[status.sex].initiation_age, sim_object.models[status.sex], st_repro_organ, meteo, constants, sim_object)
    PlantSimEngine.run!(sim_object.models[status.sex].final_potential_biomass, sim_object.models[status.sex], st_repro_organ, meteo, constants, sim_object)
end