struct ReproductiveOrganEmission <: AbstractReproductive_Organ_EmissionModel end

PlantSimEngine.inputs_(::ReproductiveOrganEmission) = NamedTuple()

PlantSimEngine.outputs_(::ReproductiveOrganEmission) = NamedTuple()

"""
    add_reproductive_organ!(...)

Add a new reproductive organ to a phytomer.
"""
function PlantSimEngine.run!(::ReproductiveOrganEmission, models, status, meteo, constants, mtg)
    @assert mtg.MTG.symbol == "Phytomer" "The function should be applied to a Phytomer, but is applied to a $(mtg.MTG.symbol)"
    current_step = rownumber(status)

    scene = get_root(mtg)
    scene[:mtg_node_count] += 1

    internode = mtg[1]

    # Create the new phytomer as a child of the last one (younger one):
    repro_organ = addchild!(
        internode, # parent
        scene[:mtg_node_count], # unique ID
        MultiScaleTreeGraph.MutableNodeMTG("+", status.sex, scene[:mtg_node_count], 4), # MTG
        Dict{Symbol,Any}(
            :models => copy(scene[:all_models][status.sex]),
        ), # Attributes
        type=status.sex == "Female" ? Female() : Male(),
    )

    # Initialisations:

    # Compute the initiation age of the organ:
    PlantSimEngine.run!(repro_organ[:models].models.initiation_age, repro_organ[:models].models, repro_organ[:models].status[current_step], meteo, constants, repro_organ)
    PlantSimEngine.run!(repro_organ[:models].models.final_potential_biomass, repro_organ[:models].models, repro_organ[:models].status[current_step], meteo, constants, repro_organ)

    # repro_organ[:models].status[current_step].biomass = 0.0
    repro_organ[:models].status[current_step].carbon_demand = 0.0
end