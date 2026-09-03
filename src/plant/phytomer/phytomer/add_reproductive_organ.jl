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
    graph_node_count=PlantSimEngine.Default(m.graph_node_count_init), # Also modified in the model, but can't be an output, other models have it too
    phytomer_count=PlantSimEngine.Default(m.phytomer_count_init),
    plant_age=PlantSimEngine.Required(Real),
    TT_since_init=PlantSimEngine.Required(Real),
    sex=PlantSimEngine.Required(Symbol),
    state=PlantSimEngine.Required(Symbol),
    emit_reproductive_organ=PlantSimEngine.Required(Bool),
)

PlantSimEngine.outputs_(::ReproductiveOrganEmission) = NamedTuple()

"""
    add_reproductive_organ!(...)

Add a new reproductive organ to a phytomer.
"""
function PlantSimEngine.run!(m::ReproductiveOrganEmission, status, environment, constants, context)
    status.emit_reproductive_organ || return nothing
    phytomer = PlantSimEngine.source_node(context)
    @assert symbol(phytomer) == m.phytomer_symbol "The function should be applied to a $(m.phytomer_symbol), but is applied to a $(symbol(phytomer))"
    @assert status.sex in (m.male_symbol, m.female_symbol)
    status.graph_node_count += 1

    # Create the new organ as a child of the phytomer:
    st_reproductive_organ = PlantSimEngine.add_organ!(
        phytomer[1], # The phytomer's internode is its first child
        context,
        :+,
        Symbol(status.sex),
        4;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}(),
        initial_status=(
            initiation_age=copy(status.plant_age),
            TT_since_init=copy(status.TT_since_init),
            state=status.state,
            sex=status.sex,
        ),
    )
    reproductive_organ_id = PlantSimEngine.object_id(context, st_reproductive_organ)
    organ = Symbol(lowercase(string(status.sex)))
    PlantSimEngine.run_call!(
        context,
        Symbol(organ, "_initiation_age");
        objects=reproductive_organ_id,
    )
    PlantSimEngine.run_call!(
        context,
        Symbol(organ, "_final_potential_biomass");
        objects=reproductive_organ_id,
    )
    PlantSimEngine.run_initializer!(
        context,
        Symbol(organ, "_initial_maintenance_respiration"),
        reproductive_organ_id,
    )
    # Note: we initialize TT_since_init to the one from the phytomer, as the parameters for development are given from the phytomer point of view.
    # This is because the reproductive organ is only instantiated when its sex is determined, but it started to grow at the same time as the phytomer.
end
