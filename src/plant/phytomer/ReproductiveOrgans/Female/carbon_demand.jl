raw"""
    FemaleCarbonDemandModel(; respiration_cost=1.44,
        respiration_cost_oleosynthesis=3.2, TT_flowering=10530.0,
        duration_bunch_development=1215.0, duration_fruit_setting=405.0,
        fraction_period_oleosynthesis=0.8, fraction_period_stalk=0.2)

Carbon demand of a female inflorescence, including growth left unfinished by
previous carbon allocation deficits. Non-oil fruit, oil, and stalk each retain
their phenological growth schedule and final dry-mass potential. Unfunded growth
remains in the demand until harvest or abortion, even after the component's
original growth window has ended.

For each component, let `S` be the unique dry matter scheduled so far, `B₀` its
initial dry mass, `Bprev` its previous actual dry mass, `P` its final potential,
`d` today's scheduled assimilate requirement, and `c` its construction cost:

```math
S_t = \max\{S_{t-1},\;\min[\max(0,P_t-B_0),\;S_{t-1}+d_t/c]\},
\qquad D_t = c\max\{0,\min(P_t,B_0+S_t)-B_{t-1}\}.
```

This replaces a fixed daily demand that discarded growth missed on earlier
days. It does not create biomass: [`FemaleBiomass`](@ref) converts the carbon
actually allocated to each component into dry mass using the same construction
costs. A higher demand can increase the bunch's share of available carbon and
reserves, so it also changes competition with other organs. No additional
recovery-rate limit is imposed, and harvest is not delayed.

# Parameters

- `respiration_cost`: non-oil fruit and stalk construction cost
  (g CH2O-equivalent allocated per gDM produced).
- `respiration_cost_oleosynthesis`: oil construction cost (same units).
- `TT_flowering`: flowering time since phytomer initiation (degree days).
- `duration_fruit_setting`: thermal time from flowering to fruit set.
- `duration_bunch_development`: thermal time from fruit set to harvest.
- `fraction_period_oleosynthesis`: fraction of bunch development used for oil
  synthesis.
- `fraction_period_stalk`: fraction of the pre-harvest period used to schedule
  stalk growth.

# Inputs and coupling

The native final potentials are non-oil and oil dry mass per fruit and total
stalk dry mass. `fruits_number`, `state`, `TT_since_init`, and daily effective
temperature `TEff` determine today's scheduled growth. The three
`catchup_previous_*_gDM` inputs must be bound with `PreviousTimeStep` to the
corresponding actual `FemaleBiomass` stocks. XPalm's standard scene does this
automatically; custom assemblies must provide these temporal bindings too.

# Outputs and diagnostics

`carbon_demand` and its three component demands are daily assimilate requests
(g CH2O-equivalent/day). `catchup_scheduled_*_gDM` counts unique scheduled dry
matter once. `catchup_new_due_*_gCH2O` is today's new requirement and
`catchup_outstanding_*_gCH2O` the request before allocation.
`catchup_retry_requested_gCH2O` is the repeated part of that request. Cumulative
requested carbon includes retries and is therefore not a biomass total.

The first terminal day freezes the residual unfunded-growth diagnostic before
harvest clears biomass. Later terminal days request no carbon. A finalized
organ cannot be reactivated.
"""
struct FemaleCarbonDemandModel{T} <: AbstractCarbon_DemandModel
    respiration_cost::T
    respiration_cost_oleosynthesis::T
    TT_flowering::T
    TT_fruiting::T
    duration_bunch_development::T
    duration_oleosynthesis::T
    duration_dev_stalk::T
end

function FemaleCarbonDemandModel(;
    respiration_cost=1.44,
    respiration_cost_oleosynthesis=3.2,
    TT_flowering=10530.0,
    duration_bunch_development=1215.0,
    duration_fruit_setting=405.0,
    fraction_period_oleosynthesis=0.8,
    fraction_period_stalk=0.2
)
    @assert duration_bunch_development > 0 "`duration_bunch_development` must be > 0"
    @assert duration_fruit_setting > 0 "`duration_fruit_setting` must be > 0"
    @assert TT_flowering > 0.0 "TT_flowering must be > 0.0"
    @assert 0.0 <= fraction_period_oleosynthesis <= 1.0 "fraction_period_oleosynthesis must be between 0 and 1"
    @assert 0.0 <= fraction_period_stalk <= 1.0 "fraction_period_stalk must be between 0 and 1"
    TT_fruiting = TT_flowering + duration_fruit_setting

    duration_oleosynthesis = fraction_period_oleosynthesis * duration_bunch_development
    duration_dev_stalk = fraction_period_stalk * (TT_fruiting + duration_bunch_development)

    FemaleCarbonDemandModel(
        promote(
            respiration_cost,
            respiration_cost_oleosynthesis,
            TT_flowering,
            TT_fruiting,
            duration_bunch_development,
            duration_oleosynthesis,
            duration_dev_stalk
        )...
    )
end

PlantSimEngine.inputs_(m::FemaleCarbonDemandModel) = merge(
    (
        final_potential_biomass_non_oil_fruit=PlantSimEngine.Required(Real),
        final_potential_biomass_oil_fruit=PlantSimEngine.Required(Real),
        final_potential_biomass_stalk=PlantSimEngine.Required(Real),
        fruits_number=PlantSimEngine.Required(Real),
        TEff=PlantSimEngine.Required(Real),
        state=PlantSimEngine.Required(Symbol),
        TT_since_init=PlantSimEngine.Required(Real),
    ),
    (
        # Temporal inputs need bootstrap defaults in PlantSimEngine 0.15.
        # The XPalm application explicitly binds all three to previous actual
        # FemaleBiomass stocks; custom assemblies must do the same.
        catchup_previous_non_oil_gDM=PlantSimEngine.Default(zero(m.TT_flowering)),
        catchup_previous_oil_gDM=PlantSimEngine.Default(zero(m.TT_flowering)),
        catchup_previous_stalk_gDM=PlantSimEngine.Default(zero(m.TT_flowering)),
    ),
)

function PlantSimEngine.outputs_(m::FemaleCarbonDemandModel)
    z = zero(m.TT_flowering)
    return merge((carbon_demand=z, carbon_demand_oil=z,
        carbon_demand_non_oil=z, carbon_demand_stalk=z), (
        catchup_initialized=false,
        catchup_finalized=false,
        catchup_initial_non_oil_gDM=z,
        catchup_initial_oil_gDM=z,
        catchup_initial_stalk_gDM=z,
        catchup_scheduled_non_oil_gDM=z,
        catchup_scheduled_oil_gDM=z,
        catchup_scheduled_stalk_gDM=z,
        catchup_new_due_non_oil_gCH2O=z,
        catchup_new_due_oil_gCH2O=z,
        catchup_new_due_stalk_gCH2O=z,
        catchup_outstanding_non_oil_gCH2O=z,
        catchup_outstanding_oil_gCH2O=z,
        catchup_outstanding_stalk_gCH2O=z,
        catchup_retry_requested_gCH2O=z,
        catchup_retry_requested_cum_gCH2O=z,
        catchup_effective_requested_cum_gCH2O=z,
    ))
end

function PlantSimEngine.variable_contracts_(m::FemaleCarbonDemandModel)
    flag = PlantSimEngine.VariableContract(
        unit=:dimensionless, basis=:object, aggregation=:state, extent=:intensive,
    )
    return merge((
        final_potential_biomass_non_oil_fruit=_STRUCTURAL_DRY_MASS,
        final_potential_biomass_oil_fruit=_STRUCTURAL_DRY_MASS,
        final_potential_biomass_stalk=_STRUCTURAL_DRY_MASS,
        carbon_demand=_DAILY_CH2O_EQUIVALENT_FLOW,
        carbon_demand_oil=_DAILY_CH2O_EQUIVALENT_FLOW,
        carbon_demand_non_oil=_DAILY_CH2O_EQUIVALENT_FLOW,
        carbon_demand_stalk=_DAILY_CH2O_EQUIVALENT_FLOW,
    ), (
        catchup_initialized=flag,
        catchup_finalized=flag,
        catchup_previous_non_oil_gDM=_STRUCTURAL_DRY_MASS,
        catchup_previous_oil_gDM=_STRUCTURAL_DRY_MASS,
        catchup_previous_stalk_gDM=_STRUCTURAL_DRY_MASS,
        catchup_initial_non_oil_gDM=_STRUCTURAL_DRY_MASS,
        catchup_initial_oil_gDM=_STRUCTURAL_DRY_MASS,
        catchup_initial_stalk_gDM=_STRUCTURAL_DRY_MASS,
        catchup_scheduled_non_oil_gDM=_STRUCTURAL_DRY_MASS,
        catchup_scheduled_oil_gDM=_STRUCTURAL_DRY_MASS,
        catchup_scheduled_stalk_gDM=_STRUCTURAL_DRY_MASS,
        catchup_new_due_non_oil_gCH2O=_DAILY_CH2O_EQUIVALENT_FLOW,
        catchup_new_due_oil_gCH2O=_DAILY_CH2O_EQUIVALENT_FLOW,
        catchup_new_due_stalk_gCH2O=_DAILY_CH2O_EQUIVALENT_FLOW,
        catchup_outstanding_non_oil_gCH2O=_DAILY_CH2O_EQUIVALENT_FLOW,
        catchup_outstanding_oil_gCH2O=_DAILY_CH2O_EQUIVALENT_FLOW,
        catchup_outstanding_stalk_gCH2O=_DAILY_CH2O_EQUIVALENT_FLOW,
        catchup_retry_requested_gCH2O=_DAILY_CH2O_EQUIVALENT_FLOW,
        catchup_retry_requested_cum_gCH2O=_ACCUMULATED_CH2O_EQUIVALENT,
        catchup_effective_requested_cum_gCH2O=_ACCUMULATED_CH2O_EQUIVALENT,
    ))
end

"""Advance a unique component schedule, then request its unfunded part."""
function _catchup_component_request(scheduled, initial, target, previous, native_demand, cost;
    enabled=true)
    all(isfinite, (scheduled, initial, previous, native_demand, cost)) ||
        throw(ArgumentError("Catch-up demand requires finite schedule, stocks and costs"))
    cost > zero(cost) || throw(ArgumentError("Construction cost must be positive"))
    min(scheduled, initial, previous, native_demand) >= zero(scheduled) ||
        throw(ArgumentError("Catch-up stocks and native demands must be nonnegative"))
    if !enabled
        return (
            scheduled=scheduled + native_demand / cost,
            new_due=native_demand,
            request=native_demand,
            retry=zero(native_demand),
            outstanding=native_demand,
        )
    end
    isfinite(target) && target >= zero(target) ||
        throw(ArgumentError("A native component target must be finite and nonnegative"))
    maximum_new_mass = max(zero(target), target - initial)
    next_scheduled = max(scheduled,
        min(maximum_new_mass, scheduled + native_demand / cost))
    new_due = max(zero(native_demand), next_scheduled - scheduled) * cost
    due_stock = min(target, initial + next_scheduled)
    request = max(zero(native_demand), due_stock - previous) * cost
    retry = max(zero(native_demand), request - new_due)
    return (scheduled=next_scheduled, new_due=new_due, request=request,
        retry=retry, outstanding=request)
end

function PlantSimEngine.run!(m::FemaleCarbonDemandModel, st, environment,
    constants, context=nothing)
    terminal = st.state in (:harvested, :aborted)
    st.catchup_finalized && !terminal && throw(ArgumentError(
        "A finalized female catch-up organ cannot be reactivated"))
    _scheduled_female_demand!(m, st)
    z = zero(st.carbon_demand)
    st.catchup_new_due_non_oil_gCH2O = z
    st.catchup_new_due_oil_gCH2O = z
    st.catchup_new_due_stalk_gCH2O = z
    st.catchup_retry_requested_gCH2O = z
    if st.catchup_finalized
        # Native harvest resets component biomass after this demand model runs.
        # Its zero stocks on later days must not overwrite the terminal ledger.
        st.carbon_demand_non_oil = z
        st.carbon_demand_oil = z
        st.carbon_demand_stalk = z
        st.carbon_demand = z
        return nothing
    end
    if !st.catchup_initialized
        st.catchup_initial_non_oil_gDM = st.catchup_previous_non_oil_gDM
        st.catchup_initial_oil_gDM = st.catchup_previous_oil_gDM
        st.catchup_initial_stalk_gDM = st.catchup_previous_stalk_gDM
        st.catchup_initialized = true
    end
    cn = m.respiration_cost
    co = m.respiration_cost_oleosynthesis
    st.catchup_outstanding_non_oil_gCH2O = max(z,
        st.catchup_initial_non_oil_gDM + st.catchup_scheduled_non_oil_gDM -
        st.catchup_previous_non_oil_gDM) * cn
    st.catchup_outstanding_oil_gCH2O = max(z,
        st.catchup_initial_oil_gDM + st.catchup_scheduled_oil_gDM -
        st.catchup_previous_oil_gDM) * co
    st.catchup_outstanding_stalk_gCH2O = max(z,
        st.catchup_initial_stalk_gDM + st.catchup_scheduled_stalk_gDM -
        st.catchup_previous_stalk_gDM) * cn
    if terminal
        st.catchup_finalized = true
        st.carbon_demand_non_oil = z
        st.carbon_demand_oil = z
        st.carbon_demand_stalk = z
        st.carbon_demand = z
        return nothing
    end
    valid_fruit_count = st.fruits_number >= zero(st.fruits_number)
    if !valid_fruit_count
        iszero(st.carbon_demand_non_oil) && iszero(st.carbon_demand_oil) ||
            throw(ArgumentError("Fruit demand must be zero before a valid fruit count exists"))
    end
    nonoil_target = valid_fruit_count ?
        st.fruits_number * st.final_potential_biomass_non_oil_fruit : z
    oil_target = valid_fruit_count ?
        st.fruits_number * st.final_potential_biomass_oil_fruit : z
    nonoil = _catchup_component_request(st.catchup_scheduled_non_oil_gDM,
        st.catchup_initial_non_oil_gDM, nonoil_target,
        st.catchup_previous_non_oil_gDM, st.carbon_demand_non_oil, cn;
        enabled=valid_fruit_count)
    oil = _catchup_component_request(st.catchup_scheduled_oil_gDM,
        st.catchup_initial_oil_gDM, oil_target,
        st.catchup_previous_oil_gDM, st.carbon_demand_oil, co;
        enabled=valid_fruit_count)
    stalk = _catchup_component_request(st.catchup_scheduled_stalk_gDM,
        st.catchup_initial_stalk_gDM, st.final_potential_biomass_stalk,
        st.catchup_previous_stalk_gDM, st.carbon_demand_stalk, cn)
    st.catchup_scheduled_non_oil_gDM = nonoil.scheduled
    st.catchup_scheduled_oil_gDM = oil.scheduled
    st.catchup_scheduled_stalk_gDM = stalk.scheduled
    st.catchup_new_due_non_oil_gCH2O = nonoil.new_due
    st.catchup_new_due_oil_gCH2O = oil.new_due
    st.catchup_new_due_stalk_gCH2O = stalk.new_due
    st.catchup_outstanding_non_oil_gCH2O = nonoil.outstanding
    st.catchup_outstanding_oil_gCH2O = oil.outstanding
    st.catchup_outstanding_stalk_gCH2O = stalk.outstanding
    st.carbon_demand_non_oil = nonoil.request
    st.carbon_demand_oil = oil.request
    st.carbon_demand_stalk = stalk.request
    st.carbon_demand = nonoil.request + oil.request + stalk.request
    st.catchup_retry_requested_gCH2O = nonoil.retry + oil.retry + stalk.retry
    st.catchup_retry_requested_cum_gCH2O += st.catchup_retry_requested_gCH2O
    st.catchup_effective_requested_cum_gCH2O += st.carbon_demand
    return nothing
end

# Phenology schedules each component's potential growth. The public demand
# calculation keeps any unfunded part available on subsequent days.
function _scheduled_female_demand!(m::FemaleCarbonDemandModel, status)

    # We initialize the carbon demand at 0.0 because we add to it with some conditions below
    # If it is harvested or there are no fruits, there is no carbon demand
    status.carbon_demand_stalk = 0.0
    status.carbon_demand_non_oil = 0.0
    status.carbon_demand_oil = 0.0
    status.carbon_demand = 0.0

    if status.state == :harvested || status.state == :aborted
        return nothing
    end

    # If there are no fruits, there is no carbon demand
    if status.fruits_number > 0
        # As soon as we have fruits:
        if status.TT_since_init >= m.TT_fruiting
            status.carbon_demand_non_oil = status.fruits_number *
                                           status.final_potential_biomass_non_oil_fruit *
                                           m.respiration_cost *
                                           (status.TEff / m.duration_bunch_development)
            status.carbon_demand += status.carbon_demand_non_oil
        end

        if status.state == :oleosynthesis
            status.carbon_demand_oil = status.fruits_number *
                                       status.final_potential_biomass_oil_fruit *
                                       m.respiration_cost_oleosynthesis *
                                       (status.TEff / m.duration_oleosynthesis)
            status.carbon_demand += status.carbon_demand_oil
        end
    end

    # Carbon demand for the stalk:
    if status.TT_since_init >= m.TT_flowering + m.duration_dev_stalk
        status.carbon_demand_stalk = 0.0
    else
        status.carbon_demand_stalk = status.final_potential_biomass_stalk *
                                     (status.TEff / m.duration_dev_stalk) *
                                     m.respiration_cost
        status.carbon_demand += status.carbon_demand_stalk
    end
    return nothing
end
