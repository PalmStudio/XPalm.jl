"""
    add_reproductive_organ!(...)

Add a new reproductive organ to a phytomer.
"""
struct ReproductiveOrganEmission <: AbstractReproductive_Organ_EmissionModel
    phytomer_count_init::Int
    graph_node_count_init::Int
    phytomer_symbol::Symbol
    male_symbol::Symbol
    female_symbol::Symbol
end

function ReproductiveOrganEmission(mtg::MultiScaleTreeGraph.Node; phytomer_symbol=:Phytomer, male_symbol=:Male, female_symbol=:Female)
    phytomers = MultiScaleTreeGraph.descendants(mtg, symbol=phytomer_symbol, self=true)
    ReproductiveOrganEmission(length(phytomers), length(mtg), phytomer_symbol, male_symbol, female_symbol)
end

PlantSimEngine.inputs_(m::ReproductiveOrganEmission) = (
    graph_node_count=m.graph_node_count_init, # Also modified in the model, but can't be an output, other models have it too
    phytomer_count=m.phytomer_count_init,
    TT_since_init=-Inf,
)

PlantSimEngine.outputs_(::ReproductiveOrganEmission) = NamedTuple()

"""
    add_reproductive_organ!(...)

Add a new reproductive organ to a phytomer.
"""
function PlantSimEngine.run!(m::ReproductiveOrganEmission, models, status, meteo, constants, sim_object)
    @assert symbol(status.node) == :Phytomer "The function should be applied to a Phytomer, but is applied to a $(symbol(status.node))"
    @assert status.sex in [:undetermined, m.male_symbol, m.female_symbol]
    status.graph_node_count += 1

    # Create the new organ as a child of the phytomer:
    PlantSimEngine.add_organ!(
        status.node[1], # The phytomer's internode is its first child 
        sim_object,
        :+,
        Symbol(status.sex),
        4;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}(),
        initial_status=(
            initiation_age=status.initiation_age,
            TT_since_init=copy(status.TT_since_init),
            state=status.state,
            sex=status.sex,
        ),
        kind=:plant,
    )
    # Note: we initialize TT_since_init to the one from the phytomer, as the parameters for development are given from the phytomer point of view.
    # This is because the reproductive organ is only instantiated when its sex is determined, but it started to grow at the same time as the phytomer.
end
