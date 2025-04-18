"""
    add_reproductive_organ!(...)

Add a new reproductive organ to a phytomer.
"""
struct ReproductiveOrganEmission <: AbstractReproductive_Organ_EmissionModel
    phytomer_count_init::Int
    graph_node_count_init::Int
    phytomer_symbol::String
    male_symbol::String
    female_symbol::String
end

function ReproductiveOrganEmission(mtg::MultiScaleTreeGraph.Node; phytomer_symbol="Phytomer", male_symbol="Male", female_symbol="Female")
    phytomers = MultiScaleTreeGraph.descendants(mtg, symbol=phytomer_symbol, self=true)
    ReproductiveOrganEmission(length(phytomers), length(mtg), phytomer_symbol, male_symbol, female_symbol)
end

PlantSimEngine.inputs_(m::ReproductiveOrganEmission) = (
    graph_node_count=m.graph_node_count_init, # Also modified in the model, but can't be an output, other models have it too
    phytomer_count=m.phytomer_count_init,
    TT_since_init=-Inf,
)

PlantSimEngine.outputs_(::ReproductiveOrganEmission) = NamedTuple()
PlantSimEngine.dep(m::ReproductiveOrganEmission) = (
    initiation_age=AbstractInitiation_AgeModel => [m.male_symbol, m.female_symbol],
    final_potential_biomass=AbstractFinal_Potential_BiomassModel => [m.male_symbol, m.female_symbol],
)

"""
    add_reproductive_organ!(...)

Add a new reproductive organ to a phytomer.
"""
function PlantSimEngine.run!(m::ReproductiveOrganEmission, models, status, meteo, constants, sim_object)
    @assert symbol(status.node) == "Phytomer" "The function should be applied to a Phytomer, but is applied to a $(symbol(status.node))"
    @assert status.sex in ["undetermined", m.male_symbol, m.female_symbol]
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
    st_repro_organ.TT_since_init = copy(status.TT_since_init)
    # Note: we initialize TT_since_init to the one from the phytomer, as the parameters for development are given from the phytomer point of view.
    # This is because the reproductive organ is only instantiated when its sex is determined, but it started to grow at the same time as the phytomer.
end