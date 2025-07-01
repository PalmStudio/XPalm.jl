
# struct fields: vpalm parameters, rng, 
# inputs: phytomer_count (plant scale), phytomer node (model at phytomer scale), stem_height, stem_diameter, parameters, rng
unique_mtg_id = Ref(max_id(plant) + 1)
nb_internodes = status.phytomer_count
internode = phytomer[1]
leaf = internode[1]
leaf.plantsimengine
rank = leaf[:plantsimengine_status].rank

internode[:plantsimengine_status].height
internode[:plantsimengine_status].radius

parameters = parameters["vpalm"]

i = MultiScaleTreeGraph.index(internode) # index of the internode
internode.width = internode[:plantsimengine_status].radius * 2.0u"m"
internode.length = internode[:plantsimengine_status].height
internode.rank = rank
internode.Orthotropy = 0.05u"°"
internode.XEuler = VPalm.phyllotactic_angle(parameters["phyllotactic_angle_mean"], parameters["phyllotactic_angle_sd"]; rng=rng)

leaf = internode[1]
leaf.rank = rank
leaf.is_alive = true

biomass_leaf = uconvert(u"kg", leaf[:plantsimengine_status].biomass * u"g")
current_length = VPalm.rachis_length_from_biomass(biomass_leaf, parameters["leaf_length_intercept"], parameters["leaf_length_slope"])
VPalm.compute_properties_leaf!(leaf, rank, true, current_length, parameters, rng)

# Build the petiole
petiole_node = VPalm.petiole(unique_mtg_id, i, 5, leaf.rachis_length, leaf.zenithal_insertion_angle, leaf.zenithal_cpoint_angle, parameters; rng=rng)
addchild!(leaf, petiole_node)

# Build the rachis
rachis_node = rachis(unique_mtg_id, i, 5, rank, leaf.rachis_length, petiole_node.height_cpoint, petiole_node.width_cpoint, leaf.zenithal_cpoint_angle, biomass_leaf, parameters; rng=rng)
addchild!(petiole_node, rachis_node)

# Add the leaflets to the rachis:
leaflets!(unique_mtg_id, rachis_node, 5, leaf.rank, leaf.rachis_length, parameters; rng=rng)
