raw"""
    CatchUpFemaleCarbonDemandModel(baseline::FemaleCarbonDemandModel)
    CatchUpFemaleCarbonDemandModel(; kwargs...)

Retry unfunded, previously scheduled female-inflorescence growth while the
organ is active. `kwargs` are forwarded to [`FemaleCarbonDemandModel`](@ref).

The baseline still determines when non-oil fruit, oil, and stalk dry matter
become due. Each component's unique schedule is capped by its native final
potential. Unfinished growth remains in the request until harvest or abortion,
including after that component's original scheduling window has ended.

For component `j`, let `S` be unique scheduled new dry matter, `B₀` initial dry
matter, `Bprev` previous actual dry matter, `P` the current native final potential,
`d` baseline daily CH2O-equivalent demand, and `c` construction cost. The update is

```math
S_t = \max\{S_{t-1},\;\min[\max(0,P_t-B_0),\;S_{t-1}+d_t/c]\},
\qquad D_t = c\max\{0,\min(P_t,B_0+S_t)-B_{t-1}\}.
```

Actual growth still requires native carbon allocation: component dry-matter
increment is its allocated CH2O-equivalent mass divided by its construction
cost. Requests do not create carbon or biomass and cannot postpone harvest.
Repeated requests are not additional unique growth potential.

This is an experimental upper-bound recovery hypothesis: no additional
physiological catch-up rate is imposed. Raising an organ's request can increase
its share of existing assimilates and reserves and change competition with all
other organs. Recalibration is required when comparing predictive performance.
No observations, forcing flags, imposed endpoints, or external corrections are
required by this model. The fixed-schedule model remains the package default.

# Additional inputs

- `catchup_previous_non_oil_gDM`, `catchup_previous_oil_gDM`,
  `catchup_previous_stalk_gDM`: previous actual component dry masses (gDM), bound
  explicitly with `PreviousTimeStep` to the corresponding `FemaleBiomass` outputs.

# Diagnostics

`catchup_scheduled_*_gDM` counts newly scheduled dry matter once;
`catchup_new_due_*_gCH2O` is today's unique new assimilate requirement;
`catchup_outstanding_*_gCH2O` is the component request before today's allocation;
`catchup_retry_requested_gCH2O` is repeated demand. The first terminal day freezes
the unfunded-growth diagnostic before native harvest clears biomass. Later
terminal days request no carbon and cannot reinterpret cleared stocks as new
unfunded growth. A finalized organ cannot be reactivated.
"""
struct CatchUpFemaleCarbonDemandModel{M<:FemaleCarbonDemandModel} <: AbstractCarbon_DemandModel
    baseline::M
end

CatchUpFemaleCarbonDemandModel(; kwargs...) =
    CatchUpFemaleCarbonDemandModel(FemaleCarbonDemandModel(; kwargs...))

PlantSimEngine.inputs_(m::CatchUpFemaleCarbonDemandModel) = merge(
    PlantSimEngine.inputs_(m.baseline),
    (
        # Temporal inputs need bootstrap defaults in PlantSimEngine 0.15.
        # The XPalm application explicitly binds all three to previous actual
        # FemaleBiomass stocks; custom assemblies must do the same.
        catchup_previous_non_oil_gDM=PlantSimEngine.Default(zero(m.baseline.TT_flowering)),
        catchup_previous_oil_gDM=PlantSimEngine.Default(zero(m.baseline.TT_flowering)),
        catchup_previous_stalk_gDM=PlantSimEngine.Default(zero(m.baseline.TT_flowering)),
    ),
)

function PlantSimEngine.outputs_(m::CatchUpFemaleCarbonDemandModel)
    z = zero(m.baseline.TT_flowering)
    return merge(PlantSimEngine.outputs_(m.baseline), (
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

function PlantSimEngine.variable_contracts_(m::CatchUpFemaleCarbonDemandModel)
    flag = PlantSimEngine.VariableContract(
        unit=:dimensionless, basis=:object, aggregation=:state, extent=:intensive,
    )
    return merge(PlantSimEngine.variable_contracts_(m.baseline), (
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

function PlantSimEngine.run!(m::CatchUpFemaleCarbonDemandModel, st, environment,
    constants, context=nothing)
    terminal = st.state in (:harvested, :aborted)
    st.catchup_finalized && !terminal && throw(ArgumentError(
        "A finalized female catch-up organ cannot be reactivated"))
    PlantSimEngine.run!(m.baseline, st, environment, constants, context)
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
    cn = m.baseline.respiration_cost
    co = m.baseline.respiration_cost_oleosynthesis
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
