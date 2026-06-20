

struct _MappedModel{M,V}
    model::M
    mapped_variables::V
end

_MappedModel(; model, mapped_variables=()) = _MappedModel(model, mapped_variables)

struct _BoundModel{M,B}
    model::M
    bindings::B
end

_input_bindings(; kwargs...) = model -> _BoundModel(model, (; kwargs...))

function _source_scope(target_scale::Symbol, source_scale::Symbol)
    source_scale == target_scale && return PlantSimEngine.Self()
    source_scale == :Scene && return PlantSimEngine.SceneScope()
    source_scale == :Soil && return PlantSimEngine.SceneScope()
    source_scale == :Plant && return PlantSimEngine.SelfPlant()
    source_scale == :Phytomer && return PlantSimEngine.Ancestor(scale=:Phytomer)
    target_scale == :Scene && return PlantSimEngine.SceneScope()
    target_scale == :Plant && return PlantSimEngine.Subtree()
    return PlantSimEngine.SelfPlant()
end

function _one_source(target_scale::Symbol, source_scale::Symbol, source_var::Symbol; process=nothing)
    scope = _source_scope(target_scale, source_scale)
    kwargs = isnothing(process) ?
             (; scale=source_scale, var=source_var) :
             (; scale=source_scale, var=source_var, process=process)
    if scope isa PlantSimEngine.Relation
        return PlantSimEngine.One(; kwargs..., relation=scope.relation)
    end
    return PlantSimEngine.One(; kwargs..., within=scope)
end

function _many_source(target_scale::Symbol, sources, source_var::Symbol; process=nothing)
    source_scales = Tuple(Symbol(first(source)) for source in sources)
    scope = target_scale == :Phytomer ? PlantSimEngine.Subtree() :
            target_scale in (:Scene, :Soil) ? PlantSimEngine.SceneScope() :
            target_scale == :Plant ? PlantSimEngine.Subtree() :
            PlantSimEngine.SelfPlant()
    kwargs = isnothing(process) ?
             (; scale=source_scales, var=source_var) :
             (; scale=source_scales, var=source_var, process=process)
    return PlantSimEngine.Many(; kwargs..., within=scope)
end

function _normalize_mapping_pair(binding)
    binding isa PreviousTimeStep && return binding => (nothing => binding.variable)
    binding isa Pair || error("Expected an XPalm mapping pair, got `$(typeof(binding))`.")
    key = first(binding)
    value = last(binding)
    key isa Pair && return first(key) => (last(key) => value)
    return key => value
end

function _selector_from_mapping(target_scale::Symbol, local_var::Symbol, source)
    if source isa Pair && isnothing(first(source))
        return _one_source(target_scale, target_scale, Symbol(last(source)))
    elseif source isa Symbol
        return _one_source(target_scale, source, local_var)
    elseif source isa Pair
        return _one_source(target_scale, Symbol(first(source)), Symbol(last(source)))
    elseif source isa AbstractVector || source isa Tuple
        isempty(source) && error("XPalm mapping for `$(local_var)` has no source.")
        pairs = Tuple(source)
        all(src -> src isa Pair, pairs) || error(
            "Vector mappings for `$(local_var)` must contain `scale => variable` pairs."
        )
        source_vars = unique(Symbol(last(src)) for src in pairs)
        length(source_vars) == 1 || error(
            "Scene/Object `Many(...)` mappings currently require one source variable per input. ",
            "`$(local_var)` maps from several variables: $(source_vars)."
        )
        return _many_source(target_scale, pairs, only(source_vars))
    end
    error("Unsupported XPalm mapping source `$(source)` for `$(local_var)`.")
end

function _inputs_from_mapped_variables(target_scale::Symbol, mapped_variables)
    pairs = Pair{Any,Any}[]
    for raw_binding in mapped_variables
        binding = _normalize_mapping_pair(raw_binding)
        local_var = first(binding)
        source = last(binding)
        if local_var isa PreviousTimeStep
            push!(
                pairs,
                local_var => _selector_from_mapping(target_scale, local_var.variable, source),
            )
        else
            push!(
                pairs,
                Symbol(local_var) => _selector_from_mapping(target_scale, Symbol(local_var), source),
            )
        end
    end
    return pairs
end

function _inputs_from_bound_model(target_scale::Symbol, bindings)
    input_pairs = Pair{Symbol,Any}[]
    for (input, binding) in Base.pairs(bindings)
        binding isa NamedTuple || error("XPalm input binding `$(input)` must be a NamedTuple.")
        source_scale = Symbol(binding.scale)
        process = haskey(binding, :process) ? Symbol(binding.process) : nothing
        push!(
            input_pairs,
            Symbol(input) => _one_source(target_scale, source_scale, Symbol(input); process=process),
        )
    end
    return input_pairs
end

function _calls_from_model(model)
    call_pairs = Pair{Symbol,Any}[]
    for (name, target) in Base.pairs(PlantSimEngine.dep(model))
        target isa Union{PlantSimEngine.Input,PlantSimEngine.Call,Pair} && continue
        push!(
            call_pairs,
            Symbol(name) => PlantSimEngine.One(
                relation=:self,
                process=Symbol(name),
            ),
        )
    end
    return call_pairs
end

function _scene_application(scale::Symbol, entry)
    mapped_variables = ()
    extra_inputs = Pair{Symbol,Any}[]
    model_entry = entry
    if model_entry isa _BoundModel
        append!(extra_inputs, _inputs_from_bound_model(scale, model_entry.bindings))
        model_entry = model_entry.model
    end
    if model_entry isa _MappedModel
        mapped_variables = model_entry.mapped_variables
        model_entry = model_entry.model
    end
    if model_entry isa _BoundModel
        append!(extra_inputs, _inputs_from_bound_model(scale, model_entry.bindings))
        model_entry = model_entry.model
    end

    model_entry isa Union{PlantSimEngine.AbstractModel,PlantSimEngine.ModelSpec} || error(
        "XPalm model application at scale `$(scale)` must wrap an AbstractModel or ModelSpec, got `$(typeof(model_entry))`."
    )

    base_spec = model_entry isa PlantSimEngine.ModelSpec ?
                model_entry :
                PlantSimEngine.ModelSpec(model_entry)
    model = PlantSimEngine.model_(base_spec)
    inputs = (_inputs_from_mapped_variables(scale, mapped_variables)..., extra_inputs...)
    calls = _calls_from_model(model)
    spec = PlantSimEngine.ModelSpec(
        base_spec;
        name=Symbol(scale, "__", PlantSimEngine.process(model)),
        applies_to=PlantSimEngine.Many(scale=scale),
    )
    isempty(inputs) || (spec = spec |> PlantSimEngine.Inputs(inputs...))
    isempty(calls) || (spec = spec |> PlantSimEngine.Calls(calls...))
    return spec
end

function _applications_from_model_dict(models)
    applications = Any[]
    for (scale, entries) in pairs(models)
        for entry in entries
            push!(applications, _scene_application(Symbol(scale), entry))
        end
    end
    return Tuple(applications)
end

"""
    model_applications(p; architecture=false)

Defines the scene/object model applications used in XPalm.

# Arguments

- `p`: A palm object with the parameters of the model (*e.g.* p = Palm()).
- `architecture`: A boolean indicating whether to compute the 3D architecture of the palm (default is false).

# Returns

- A tuple of `PlantSimEngine.ModelSpec` applications.
"""
function model_applications(p; architecture=false)

    # This only works for recent versions of PlantSimEngine
    models = Dict(
        :Scene => (
            ET0_BP(p.parameters["plot"]["latitude"], p.parameters["plot"]["altitude"]),
            DailyDegreeDays(),
            _MappedModel(
                model=LAIModel(p.parameters["plot"]["scene_area"]),
                mapped_variables=[:leaf_areas => [:Plant => :leaf_area],],
            ),
            Beer(k=p.parameters["radiation"]["k"]),
            GraphNodeCount(length(p.mtg)), # to have the `graph_node_count` variable initialised in the status
        ),
        :Plant => (
            DailyDegreeDays(),
            DailyPlantAgeModel(),
            PhyllochronModel(
                p.parameters["phyllochron"]["age_palm_maturity"],
                p.parameters["phyllochron"]["production_speed_initial"],
                p.parameters["phyllochron"]["production_speed_mature"],
            ),
            _MappedModel(
                model=PlantLeafAreaModel(),
                mapped_variables=[:leaf_area_leaves => [:Leaf => :leaf_area], :leaf_states => [:Leaf => :state],],
            ),
            _MappedModel(
                model=PhytomerEmission(p.mtg),
                mapped_variables=[:graph_node_count => (:Scene => :graph_node_count),],
            ),
            _MappedModel(
                model=PlantRm(),
                mapped_variables=[:Rm_organs => [:Leaf, :Internode, :Male, :Female] .=> :Rm],
            ),
            _MappedModel(
                model=SceneToPlantLightPartitioning(p.parameters["plot"]["scene_area"]),
                mapped_variables=[:aPPFD_scene => :Scene => :aPPFD, :scene_leaf_area => :Scene => :leaf_area],
            ),
            _MappedModel(
                model=RUE_FTSW(p.parameters["radiation"]["RUE"], p.parameters["radiation"]["threshold_ftsw"]),
                mapped_variables=[PreviousTimeStep(:ftsw) => (:Soil => :ftsw),],
            ),
            CarbonOfferRm(),
            _MappedModel(
                model=OrgansCarbonAllocationModel(p.parameters["carbon_demand"]["reserves"]["cost_reserve_mobilization"]),
                mapped_variables=[
                    :carbon_demand_organs => [:Leaf, :Internode, :Male, :Female] .=> :carbon_demand,
                    :carbon_allocation_organs => [:Leaf, :Internode, :Male, :Female] .=> :carbon_allocation,
                    PreviousTimeStep(:reserve_organs) => [:Leaf, :Internode] .=> :reserve,
                    PreviousTimeStep(:reserve)
                ],
            ),
            _MappedModel(
                model=OrganReserveFilling(),
                mapped_variables=[
                    :potential_reserve_organs => [:Internode, :Leaf] .=> :potential_reserve,
                    :reserve_organs => [:Internode, :Leaf] .=> :reserve,
                ],
            ),
            _MappedModel(
                model=PlantBunchHarvest(),
                mapped_variables=[
                    :biomass_bunch_harvested_organs => [:Female] .=> :biomass_bunch_harvested,
                    :biomass_stalk_harvested_organs => [:Female] .=> :biomass_stalk_harvested,
                    :biomass_fruit_harvested_organs => [:Female] .=> :biomass_fruit_harvested,
                    :biomass_bunch_harvested_cum_organs => [:Female] .=> :biomass_bunch_harvested_cum,
                    :biomass_oil_harvested_organs => [:Female] .=> :biomass_oil_harvested,
                    :biomass_oil_harvested_cum_organs => [:Female] .=> :biomass_oil_harvested_cum,
                    :biomass_oil_harvested_potential_organs => [:Female] .=> :biomass_oil_harvested_potential,
                    :biomass_oil_harvested_potential_cum_organs => [:Female] .=> :biomass_oil_harvested_potential_cum
                ],
            ),
        ),
        :Phytomer => (
            _MappedModel(
                model=InitiationAgeFromPlantAge(),
                mapped_variables=[:plant_age => :Plant,],
            ),
            # DegreeDaysFTSW(
            #     threshold_ftsw_stress=p.parameters["phyllochron"]["threshold_ftsw_stress"],
            # ), #! we should use this one instead of DailyDegreeDaysSinceInit I think
            _MappedModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => :Plant,], # Using TEff computed at plant scale
            ),
            _MappedModel(
                model=SexDetermination(
                    TT_flowering=p.parameters["phenology"]["inflorescence"]["TT_flowering"],
                    duration_abortion=p.parameters["phenology"]["inflorescence"]["duration_abortion"],
                    duration_sex_determination=p.parameters["phenology"]["inflorescence"]["duration_sex_determination"],
                    sex_ratio_min=p.parameters["reproduction"]["sex_ratio"]["sex_ratio_min"],
                    sex_ratio_ref=p.parameters["reproduction"]["sex_ratio"]["sex_ratio_ref"],
                    random_seed=p.parameters["reproduction"]["sex_ratio"]["random_seed"],
                ),
                mapped_variables=[
                    PreviousTimeStep(:carbon_offer_plant) => :Plant => :carbon_offer_after_rm,
                    PreviousTimeStep(:carbon_demand_plant) => :Plant => :carbon_demand,
                ],
            ),
            _MappedModel(
                model=ReproductiveOrganEmission(p.mtg),
                mapped_variables=[:graph_node_count => (:Scene => :graph_node_count), :phytomer_count => (:Plant => :phytomer_count)],
            ),
            _MappedModel(
                model=AbortionRate(
                    TT_flowering=p.parameters["phenology"]["inflorescence"]["TT_flowering"],
                    duration_abortion=p.parameters["phenology"]["inflorescence"]["duration_abortion"],
                    abortion_rate_max=p.parameters["reproduction"]["abortion"]["abortion_rate_max"],
                    abortion_rate_ref=p.parameters["reproduction"]["abortion"]["abortion_rate_ref"],
                    random_seed=p.parameters["reproduction"]["abortion"]["random_seed"],
                ),
                mapped_variables=[
                    PreviousTimeStep(:carbon_offer_plant) => :Plant => :carbon_offer_after_rm,
                    PreviousTimeStep(:carbon_demand_plant) => :Plant => :carbon_demand,
                ],
            ),
            _MappedModel(
                model=InfloStateModel(
                    TT_flowering=p.parameters["phenology"]["inflorescence"]["TT_flowering"],
                    duration_flowering_male=p.parameters["phenology"]["Male"]["duration_flowering_male"],
                    duration_fruit_setting=p.parameters["phenology"]["Female"]["duration_fruit_setting"],
                    duration_bunch_development=p.parameters["phenology"]["Female"]["duration_bunch_development"],
                    fraction_period_oleosynthesis=p.parameters["phenology"]["Female"]["fraction_period_oleosynthesis"],
                ), # Compute the state of the phytomer
                #! note: the mapping is artificial, we compute the state of those organs in the function directly because we use the status of a phytomer to give it to its children
                #! second note: the models should really be associated to the organs (female and male inflo + leaves)
            ),
        ),
        :Internode =>
            (
                _MappedModel(
                    model=InitiationAgeFromPlantAge(),
                    mapped_variables=[:plant_age => :Plant,],
                ),
                _MappedModel(
                    model=DailyDegreeDaysSinceInit(),
                    mapped_variables=[:TEff => :Plant,], # Using TEff computed at plant scale
                ),
                _MappedModel(
                    model=RmQ10FixedN(
                        p.parameters["respiration"]["Internode"]["Q10"],
                        p.parameters["respiration"]["Internode"]["Mr"],
                        p.parameters["respiration"]["Internode"]["T_ref"],
                        p.parameters["respiration"]["Internode"]["P_alive"],
                    ),
                    mapped_variables=[PreviousTimeStep(:biomass),],
                ),
                FinalPotentialInternodeDimensionModel(
                    p.parameters["dimensions"]["internode"]["age_max_height"],
                    p.parameters["dimensions"]["internode"]["age_max_radius"],
                    p.parameters["dimensions"]["internode"]["min_height"],
                    p.parameters["dimensions"]["internode"]["min_radius"],
                    p.parameters["dimensions"]["internode"]["max_height"],
                    p.parameters["dimensions"]["internode"]["max_radius"],
                ),
                PotentialInternodeDimensionModel(
                    inflexion_point_height=p.parameters["dimensions"]["internode"]["inflexion_point_height"],
                    slope_height=p.parameters["dimensions"]["internode"]["slope_height"],
                    inflexion_point_radius=p.parameters["dimensions"]["internode"]["inflexion_point_radius"],
                    slope_radius=p.parameters["dimensions"]["internode"]["slope_radius"],
                ),
                InternodeDimensionModel(p.parameters["carbon_demand"]["internode"]["apparent_density"]),
                InternodeCarbonDemandModel(
                    apparent_density=p.parameters["carbon_demand"]["internode"]["apparent_density"],
                    carbon_concentration=p.parameters["carbon_demand"]["internode"]["carbon_concentration"],
                    respiration_cost=p.parameters["carbon_demand"]["internode"]["respiration_cost"]
                ),
                _MappedModel(
                    model=PotentialReserveInternode(
                        p.parameters["reserves"]["nsc_max"]
                    ),
                    mapped_variables=[PreviousTimeStep(:biomass), PreviousTimeStep(:reserve)],
                ),
                InternodeBiomass(
                    initial_biomass=p.parameters["dimensions"]["internode"]["min_height"] * p.parameters["dimensions"]["internode"]["min_radius"] * p.parameters["carbon_demand"]["internode"]["apparent_density"],
                    respiration_cost=p.parameters["carbon_demand"]["internode"]["respiration_cost"]
                ),
            ),
        :Leaf => (
            _MappedModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => :Plant,], # Using TEff computed at plant scale
            ),
            FinalPotentialAreaModel(
                p.parameters["dimensions"]["leaf"]["age_first_mature_leaf"],
                p.parameters["dimensions"]["leaf"]["leaf_area_first_leaf"],
                p.parameters["dimensions"]["leaf"]["leaf_area_mature_leaf"],
            ),
            PotentialAreaModel(
                p.parameters["dimensions"]["leaf"]["inflexion_index"],
                p.parameters["dimensions"]["leaf"]["slope"],
            ),
            _MappedModel(
                model=LeafStateModel(),
                mapped_variables=[:rank_leaves => [:Leaf => :rank], :state_phytomers => [:Phytomer => :state],],
            ),
            _MappedModel(
                model=InitiationAgeFromPlantAge(),
                mapped_variables=[:plant_age => :Plant,],
            ),
            _MappedModel(
                model=LeafAreaModel(
                    p.parameters["mass_and_dimensions"]["leaf"]["lma_min"],
                    p.parameters["biomass"]["leaf"]["leaflets_biomass_contribution"],
                    p.parameters["dimensions"]["leaf"]["leaf_area_first_leaf"],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
            _MappedModel(
                model=RmQ10FixedN(
                    p.parameters["respiration"]["Leaf"]["Q10"],
                    p.parameters["respiration"]["Leaf"]["Mr"],
                    p.parameters["respiration"]["Leaf"]["T_ref"],
                    p.parameters["respiration"]["Leaf"]["P_alive"],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
            PlantSimEngine.ModelSpec(
                LeafCarbonDemandModelPotentialArea(
                    p.parameters["mass_and_dimensions"]["leaf"]["lma_min"],
                    p.parameters["carbon_demand"]["leaf"]["respiration_cost"],
                    p.parameters["biomass"]["leaf"]["leaflets_biomass_contribution"]
                )
            ) |>
            PlantSimEngine.Inputs(
                :state => PlantSimEngine.One(
                    relation=:self,
                    var=:state,
                    process=:state,
                ),
            ),
            _MappedModel(
                model=PotentialReserveLeaf(
                    p.parameters["mass_and_dimensions"]["leaf"]["lma_min"],
                    p.parameters["mass_and_dimensions"]["leaf"]["lma_max"],
                    p.parameters["biomass"]["leaf"]["leaflets_biomass_contribution"]
                ),
                mapped_variables=[PreviousTimeStep(:leaf_area), PreviousTimeStep(:reserve)],
            ),
            LeafBiomass(
                initial_biomass=p.parameters["dimensions"]["leaf"]["leaf_area_first_leaf"] * p.parameters["mass_and_dimensions"]["leaf"]["lma_min"] /
                                p.parameters["biomass"]["leaf"]["leaflets_biomass_contribution"],
                respiration_cost=p.parameters["carbon_demand"]["leaf"]["respiration_cost"],
            ),
            _MappedModel(
                model=PlantSimEngine.ModelSpec(RankLeafPruning(p.parameters["management"]["rank_leaf_pruning"])) |>
                      PlantSimEngine.Updates(:biomass; after=:biomass) |>
                      PlantSimEngine.Updates(:leaf_area; after=:leaf_area) |>
                      PlantSimEngine.Updates(:state; after=:state),
                mapped_variables=[:state_phytomers => [:Phytomer => :state],],
            ),
        ),
        :Male => (
            _MappedModel(
                model=InitiationAgeFromPlantAge(),
                mapped_variables=[:plant_age => :Plant,],
            ),
            _MappedModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => :Plant,], # Using TEff computed at plant scale
            ),
            MaleFinalPotentialBiomass(
                p.parameters["biomass"]["Male"]["max_biomass"],
                p.parameters["phenology"]["Male"]["age_mature_male"],
                p.parameters["biomass"]["Male"]["fraction_biomass_first_male"],
            ),
            _MappedModel(
                model=RmQ10FixedN(
                    p.parameters["respiration"]["Male"]["Q10"],
                    p.parameters["respiration"]["Male"]["Mr"],
                    p.parameters["respiration"]["Male"]["T_ref"],
                    p.parameters["respiration"]["Male"]["P_alive"],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
            _MappedModel(
                model=MaleCarbonDemandModel(
                    respiration_cost=p.parameters["carbon_demand"]["Male"]["respiration_cost"],
                    duration_flowering_male=p.parameters["phenology"]["Male"]["duration_flowering_male"],
                ),
                mapped_variables=[:state => :Phytomer, :TEff => :Scene], #! we should be able to remove state here, because it is written by the other scale
            ),
            MaleBiomass(
                p.parameters["carbon_demand"]["Male"]["respiration_cost"],
            ) |> _input_bindings(; state=(process=:state, scale=:Phytomer)),
        ),
        :Female => (
            _MappedModel(
                model=InitiationAgeFromPlantAge(),
                mapped_variables=[:plant_age => :Plant,],
            ),
            _MappedModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => :Plant,],
            ),
            _MappedModel(
                model=RmQ10FixedN(
                    p.parameters["respiration"]["Female"]["Q10"],
                    p.parameters["respiration"]["Female"]["Mr"],
                    p.parameters["respiration"]["Female"]["T_ref"],
                    p.parameters["respiration"]["Female"]["P_alive"],
                ),
                mapped_variables=[PreviousTimeStep(:biomass),],
            ),
            FemaleFinalPotentialFruits(
                days_increase_number_fruits=p.parameters["phenology"]["Female"]["days_increase_number_fruits"],
                days_maximum_number_fruits=p.parameters["phenology"]["Female"]["days_maximum_number_fruits"],
                fraction_first_female=p.parameters["reproduction"]["yield_formation"]["fraction_first_female"],
                potential_fruit_number_at_maturity=p.parameters["reproduction"]["yield_formation"]["potential_fruit_number_at_maturity"],
                potential_fruit_weight_at_maturity=p.parameters["reproduction"]["yield_formation"]["potential_fruit_weight_at_maturity"],
                stalk_max_biomass=p.parameters["reproduction"]["yield_formation"]["stalk_max_biomass"],
                oil_content=p.parameters["reproduction"]["yield_formation"]["oil_content"],
            ),
            _MappedModel(
                model=NumberSpikelets(
                    TT_flowering=p.parameters["phenology"]["inflorescence"]["TT_flowering"],
                    duration_dev_spikelets=p.parameters["phenology"]["Female"]["duration_dev_spikelets"],
                ),
                mapped_variables=[PreviousTimeStep(:carbon_offer_plant) => :Plant => :carbon_offer_after_rm, PreviousTimeStep(:carbon_demand_plant) => :Plant => :carbon_demand],
            ),
            _MappedModel(
                model=NumberFruits(
                    TT_flowering=p.parameters["phenology"]["inflorescence"]["TT_flowering"],
                    duration_fruit_setting=p.parameters["phenology"]["Female"]["duration_fruit_setting"],
                ),
                mapped_variables=[PreviousTimeStep(:carbon_offer_plant) => :Plant => :carbon_offer_after_rm, PreviousTimeStep(:carbon_demand_plant) => :Plant => :carbon_demand],
            ),
            FemaleCarbonDemandModel(
                respiration_cost=p.parameters["carbon_demand"]["Female"]["respiration_cost"],
                respiration_cost_oleosynthesis=p.parameters["carbon_demand"]["Female"]["respiration_cost_oleosynthesis"],
                TT_flowering=p.parameters["phenology"]["inflorescence"]["TT_flowering"],
                duration_bunch_development=p.parameters["phenology"]["Female"]["duration_bunch_development"],
                duration_fruit_setting=p.parameters["phenology"]["Female"]["duration_fruit_setting"],
                fraction_period_oleosynthesis=p.parameters["phenology"]["Female"]["fraction_period_oleosynthesis"],
                fraction_period_stalk=p.parameters["phenology"]["Female"]["fraction_period_stalk"],
            ) |> _input_bindings(; state=(process=:state, scale=:Phytomer)),
            FemaleBiomass(
                p.parameters["carbon_demand"]["Female"]["respiration_cost"],
                p.parameters["carbon_demand"]["Female"]["respiration_cost_oleosynthesis"],
            ) |> _input_bindings(; state=(process=:state, scale=:Phytomer)),
            PlantSimEngine.ModelSpec(BunchHarvest()) |>
                PlantSimEngine.Updates(
                    :biomass,
                    :biomass_stalk,
                    :biomass_fruits,
                    :biomass_oil,
                    :biomass_non_oil;
                    after=:biomass,
                ) |>
                PlantSimEngine.Updates(:fruits_number; after=:number_fruits) |>
                _input_bindings(; state=(process=:state, scale=:Phytomer)),
        ),
        :RootSystem => (
            _MappedModel(
                model=DailyDegreeDaysSinceInit(),
                mapped_variables=[:TEff => :Scene,], # Using TEff computed at scene scale
            ),
            # root_growth=RootGrowthFTSW(ini_root_depth=p.parameters["ini_root_depth"]),
            # soil_water=FTSW{RootSystem}(ini_root_depth=p.parameters["ini_root_depth"]),
            # _MappedModel(
            #     model=RmQ10FixedN(
            #         p.parameters["respiration"]["RootSystem"]["Q10"],
            #         p.parameters["respiration"]["RootSystem"]["Turn"],
            #         p.parameters["respiration"]["RootSystem"]["Prot"],
            #         p.parameters["respiration"]["RootSystem"]["N"],
            #         p.parameters["respiration"]["RootSystem"]["Gi"],
            #         p.parameters["respiration"]["RootSystem"]["Mx"],
            #         p.parameters["respiration"]["RootSystem"]["T_ref"],
            #         p.parameters["respiration"]["RootSystem"]["P_alive"],
            #     ),
            #     mapped_variables=[PreviousTimeStep(:biomass),],
            # ),
        ),
        :Soil => (
            # light_interception=Beer{Soil}(),
            _MappedModel(
                model=FTSW_BP(
                    ini_root_depth=p.parameters["water"]["ini_root_depth"],
                    H_FC=p.parameters["water"]["field_capacity"],
                    H_WP_Z1=p.parameters["water"]["wilting_point_1"],
                    Z1=p.parameters["water"]["thickness_1"],
                    H_WP_Z2=p.parameters["water"]["wilting_point_2"],
                    Z2=p.parameters["water"]["thickness_2"],
                    H_0=p.parameters["water"]["initial_water_content"],
                    KC=p.parameters["water"]["Kc"],
                    TRESH_EVAP=p.parameters["water"]["evaporation_threshold"],
                    TRESH_FTSW_TRANSPI=p.parameters["water"]["transpiration_threshold"],
                ),
                mapped_variables=[:ET0 => :Scene, :aPPFD => :Scene], # Using TEff computed at scene scale
            ),
            #! Root growth should be in the roots part, but it is a hard-coupled model with 
            #! the FSTW, so we need it here for now.
            _MappedModel(
                model=RootGrowthFTSW(ini_root_depth=p.parameters["water"]["ini_root_depth"]),
                mapped_variables=[:TEff => :Scene,], # Using TEff computed at scene scale
            ),
        )
    )


    if architecture
        vpalm = load_vpalm!()
        # Add the architecture models
        models[:Phytomer] = (
            models[:Phytomer]...,
            _MappedModel(
                model=vpalm.LeafGeometryModel(
                    mtg=p.mtg,
                    rng=Random.MersenneTwister(p.parameters["vpalm"]["seed"]),
                    vpalm_parameters=p.parameters["vpalm"]
                ),
                mapped_variables=[
                    :graph_node_count => :Scene => :graph_node_count,
                    :height_internodes => [:Internode => :height],
                    :radius_internodes => [:Internode => :radius],
                    :biomass_leaves => [:Leaf => :biomass],
                    :rank_leaves => [:Leaf => :rank],
                ],
            ),
            # "Phytomer" => (
            #     _MappedModel(
            #         model=PhytomerGeometryModel(p.mtg, p.vpalm_parameters),
            #         mapped_variables=[:phytomer_geometry => [:Phytomer => :geometry],],
            #     ),
            # ),
        )
    end
    return _applications_from_model_dict(models)
end
