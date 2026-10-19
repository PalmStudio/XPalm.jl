module XPalmFemaleCatchUpTests

using Test
using CSV, DataFrames, Dates
import PlantSimEngine as PSE
import XPalm
const M = XPalm.Models

# Kept only as a test reference for the former fixed daily calculation. There
# is no model-selection switch in XPalm's production demand implementation.
struct LegacyFixedSchedule{M} <: PSE.AbstractModel
    model::M
end
PSE.process(m::LegacyFixedSchedule) = PSE.process(m.model)
PSE.inputs_(m::LegacyFixedSchedule) = PSE.inputs_(m.model)
PSE.outputs_(m::LegacyFixedSchedule) = PSE.outputs_(m.model)
PSE.variable_contracts_(m::LegacyFixedSchedule) = PSE.variable_contracts_(m.model)
function PSE.run!(m::LegacyFixedSchedule, st, environment, constants, context=nothing)
    M._scheduled_female_demand!(m.model, st)
    return nothing
end

function fixture(T=Float64; legacy=false, initial=(T(0), T(0), T(0)),
    targets=(T(50), T(25), T(30)))
    native = M.FemaleCarbonDemandModel(;
        respiration_cost=T(1.44), respiration_cost_oleosynthesis=T(3.2),
        TT_flowering=T(100), duration_bunch_development=T(100),
        duration_fruit_setting=T(10), fraction_period_oleosynthesis=T(.8),
        fraction_period_stalk=T(.2),
    )
    demand = legacy ? LegacyFixedSchedule(native) : native
    biomass = M.FemaleBiomass(T(1.44), T(3.2))
    st = PSE.Status(merge(PSE.outputs_(demand), PSE.outputs_(biomass), (
        final_potential_biomass_non_oil_fruit=targets[1],
        final_potential_biomass_oil_fruit=targets[2],
        final_potential_biomass_stalk=targets[3], fruits_number=1,
        TEff=T(10), TT_since_init=T(120), state=:oleosynthesis,
        catchup_previous_non_oil_gDM=initial[1],
        catchup_previous_oil_gDM=initial[2], catchup_previous_stalk_gDM=initial[3],
        biomass_non_oil=initial[1], biomass_oil=initial[2],
        biomass_stalk=initial[3], biomass_fruits=initial[1] + initial[2],
        biomass=sum(initial), carbon_allocation=T(0),
    )))
    return (; native, demand, biomass, st)
end

function step!(case; supply=Inf, fraction=nothing)
    st = case.st
    st.catchup_previous_non_oil_gDM = st.biomass_non_oil
    st.catchup_previous_oil_gDM = st.biomass_oil
    st.catchup_previous_stalk_gDM = st.biomass_stalk
    PSE.run!(case.demand, st, nothing, nothing)
    st.carbon_allocation = isnothing(fraction) ?
        min(st.carbon_demand, supply) : fraction * st.carbon_demand
    PSE.run!(case.biomass, st, nothing, nothing)
    return st
end

# Allocation is synthetic only to expose the compiler's previous-step biomass
# binding. Native FemaleCarbonDemandModel and FemaleBiomass remain under test.
struct HalfFunding <: PSE.AbstractModel end
PSE.process(::HalfFunding) = :xpalm_test_half_funding
PSE.inputs_(::HalfFunding) = (carbon_demand=PSE.Required(Real),)
PSE.outputs_(::HalfFunding) = (carbon_allocation=0.0,)
PSE.variable_contracts_(::HalfFunding) = (
    carbon_demand=PSE.variable_contracts_(M.FemaleBiomass()).carbon_demand,
    carbon_allocation=PSE.variable_contracts_(M.FemaleBiomass()).carbon_allocation,
)
function PSE.run!(::HalfFunding, st, environment, constants, context=nothing)
    st.carbon_allocation = st.carbon_demand / 2
    return nothing
end

function compiled_scene(case)
    m = case.demand
    st = case.st
    initial = (
        final_potential_biomass_non_oil_fruit=st.final_potential_biomass_non_oil_fruit,
        final_potential_biomass_oil_fruit=st.final_potential_biomass_oil_fruit,
        final_potential_biomass_stalk=st.final_potential_biomass_stalk,
        fruits_number=st.fruits_number, TEff=st.TEff,
        TT_since_init=st.TT_since_init, state=st.state,
        biomass_non_oil=st.biomass_non_oil, biomass_oil=st.biomass_oil,
        biomass_stalk=st.biomass_stalk,
        biomass_fruits=st.biomass_fruits, biomass=st.biomass,
    )
    return PSE.CompositeModel(
        PSE.Object(:bunch; scale=:Female, status=PSE.Status(initial));
        applications=(
            PSE.ModelSpec(m; name=:demand, on=PSE.One(id=:bunch), inputs=(
                PSE.PreviousTimeStep(:catchup_previous_non_oil_gDM) => PSE.One(
                    within=PSE.Self(), application=:growth, var=:biomass_non_oil),
                PSE.PreviousTimeStep(:catchup_previous_oil_gDM) => PSE.One(
                    within=PSE.Self(), application=:growth, var=:biomass_oil),
                PSE.PreviousTimeStep(:catchup_previous_stalk_gDM) => PSE.One(
                    within=PSE.Self(), application=:growth, var=:biomass_stalk),
            )),
            PSE.ModelSpec(HalfFunding(); name=:funding, on=PSE.One(id=:bunch)),
            PSE.ModelSpec(case.biomass; name=:growth, on=PSE.One(id=:bunch)),
        ),
    )
end

function public_female_fixture()
    parameters = XPalm.default_parameters()
    parameters["reproduction"]["sex_ratio"]["random_seed"] = 1
    # The native probability remains clamped to 0.9. With this deterministic
    # seed and ample accumulated offer, the first phytomer becomes female.
    parameters["reproduction"]["sex_ratio"]["sex_ratio_ref"] = .9
    parameters["reproduction"]["abortion"]["abortion_rate_max"] = 0.0
    parameters["reproduction"]["abortion"]["abortion_rate_ref"] = 0.0
    weather = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data", "meteo.csv"),
        DataFrame; limit=6)
    weather.duration = fill(Day(1), nrow(weather))
    palm = XPalm.Palm(initiation_age=0, parameters=parameters)
    scene = XPalm.xpalm_scene(palm; architecture=false, environment=weather)
    simulation = PSE.run!(scene; steps=1, outputs=:none)
    phytomer = only(PSE.model_objects(scene; scale=:Phytomer))
    inflorescence = parameters["phenology"]["inflorescence"]
    phytomer.status.TT_since_init =
        inflorescence["TT_flowering"] - inflorescence["duration_abortion"]
    phytomer.status.carbon_demand_sex_determination = 1.0
    phytomer.status.carbon_offer_sex_determination = 1.0e12
    PSE.continue!(simulation; steps=1)
    female = only(PSE.model_objects(scene; scale=:Female))
    return (; parameters, scene, simulation, phytomer, female)
end

@testset "Default female demand: carbon-funded recovery and component caps" begin
    for T in (Float64, Float32)
        tol = T === Float32 ? 3e-5 : 1e-11
        native = fixture(T; legacy=true)
        recovery = fixture(T)
        @test PSE.process(recovery.demand) == PSE.process(native.demand)
        @test !any(name -> startswith(String(name), "forcing_"),
            keys(PSE.inputs_(recovery.demand)))
        @test !any(name -> startswith(String(name), "external_"),
            keys(PSE.outputs_(recovery.demand)))

        # With full funding, the native schedule is unchanged before its caps.
        for _ in 1:3
            old = step!(native)
            new = step!(recovery)
            @test new.carbon_demand ≈ old.carbon_demand rtol=tol
            @test new.biomass ≈ old.biomass rtol=tol
            @test abs(new.catchup_retry_requested_gCH2O) <= tol
        end

        # A missed day was unrecoverable under the fixed schedule. The new model
        # can fund that same scheduled dry matter after its original window.
        fixed = fixture(T; legacy=true)
        delayed = fixture(T)
        step!(fixed; supply=zero(T))
        step!(delayed; supply=zero(T))
        for case in (fixed, delayed)
            case.st.TEff = zero(T)
            case.st.TT_since_init = T(500)
            case.st.state = :fruiting
        end
        fixed_st = step!(fixed)
        # No new assimilation available means no recovery despite positive demand.
        delayed_st = step!(delayed; supply=zero(T))
        @test iszero(fixed_st.biomass)
        @test iszero(delayed_st.biomass)
        @test delayed_st.carbon_demand > zero(T)
        @test iszero(delayed_st.catchup_new_due_non_oil_gCH2O)
        @test iszero(delayed_st.catchup_new_due_oil_gCH2O)
        @test iszero(delayed_st.catchup_new_due_stalk_gCH2O)
        @test delayed_st.catchup_retry_requested_gCH2O > zero(T)
        # Later carbon genuinely funds recovery; the construction ledger closes.
        delayed_st = step!(delayed)
        @test delayed_st.biomass_non_oil ≈ T(5) rtol=tol
        @test delayed_st.biomass_oil ≈ T(3.125) rtol=tol
        @test delayed_st.biomass_stalk ≈ T(30 * 10 / 42) rtol=tol
        @test delayed_st.carbon_allocation ≈
            (delayed_st.biomass_non_oil + delayed_st.biomass_stalk) * T(1.44) +
            delayed_st.biomass_oil * T(3.2) rtol=tol
        @test abs(step!(delayed).carbon_demand) <= tol

        # Full funding never creates more than each final component potential,
        # even if native daily steps would cross the final size.
        capped = fixture(T)
        for _ in 1:20
            step!(capped)
        end
        @test capped.st.biomass_non_oil ≈ T(50) rtol=tol
        @test capped.st.biomass_oil ≈ T(25) rtol=tol
        @test capped.st.biomass_stalk ≈ T(30) rtol=tol
        @test abs(capped.st.carbon_demand) <= tol
        @test capped.st.catchup_scheduled_non_oil_gDM isa T

        # Initial biomass counts toward the target; it is not scheduled twice.
        existing = fixture(T; initial=(T(7), T(3), T(4)),
            targets=(T(10), T(5), T(6)))
        step!(existing)
        # Initial stock does not make future growth due immediately. The native
        # daily increments at these smaller targets are 1, .625 and 6*10/42 gDM.
        @test existing.st.biomass_non_oil ≈ T(8) rtol=tol
        @test existing.st.biomass_oil ≈ T(3.625) rtol=tol
        @test existing.st.biomass_stalk ≈ T(4 + 6 * 10 / 42) rtol=tol
        @test existing.st.catchup_scheduled_non_oil_gDM ≈ T(1) rtol=tol
        for _ in 1:3
            step!(existing)
        end
        @test existing.st.biomass_non_oil ≈ T(10) rtol=tol
        @test existing.st.biomass_oil ≈ T(5) rtol=tol
        @test existing.st.biomass_stalk ≈ T(6) rtol=tol
        @test existing.st.catchup_scheduled_non_oil_gDM ≈ T(3) rtol=tol
        step!(existing)
        @test existing.st.catchup_initial_non_oil_gDM == T(7)

        zeros_case = fixture(T; targets=(zero(T), zero(T), zero(T)))
        @test iszero(step!(zeros_case).biomass)
        @test iszero(zeros_case.st.carbon_demand)

        # Missing fruit count before setting must not become a negative target.
        unset = fixture(T)
        unset.st.fruits_number = -9999
        step!(unset; fraction=T(.5))
        @test iszero(unset.st.carbon_demand_non_oil)
        @test iszero(unset.st.carbon_demand_oil)
        @test unset.st.biomass_stalk > zero(T)

        # A falling target must not erase already accrued unique growth or
        # remove actual biomass. If it rises later, the same backlog can return.
        changing = fixture(T)
        step!(changing; fraction=T(.5))
        scheduled = changing.st.catchup_scheduled_non_oil_gDM
        produced = changing.st.biomass_non_oil
        changing.st.final_potential_biomass_non_oil_fruit = T(1)
        changing.st.TEff = zero(T)
        step!(changing)
        @test changing.st.catchup_scheduled_non_oil_gDM == scheduled
        @test changing.st.biomass_non_oil == produced
        @test iszero(changing.st.carbon_demand_non_oil)
        changing.st.final_potential_biomass_non_oil_fruit = T(50)
        step!(changing)
        @test changing.st.biomass_non_oil ≈ scheduled rtol=tol
        @test iszero(changing.st.catchup_new_due_non_oil_gCH2O)

        # Abort/harvest prevents growth and must tolerate terminal sentinels.
        for terminal in (:aborted, :harvested)
            case = fixture(T)
            step!(case; supply=zero(T))
            case.st.state = terminal
            case.st.fruits_number = -9999
            scheduled = case.st.catchup_scheduled_non_oil_gDM
            st = step!(case)
            @test iszero(st.carbon_demand)
            @test iszero(st.catchup_retry_requested_gCH2O)
            @test iszero(st.biomass)
            @test st.catchup_scheduled_non_oil_gDM == scheduled
            @test st.catchup_outstanding_non_oil_gCH2O > zero(T)
        end

        # Native harvest clears structural stocks. Freeze the first terminal
        # ledger so those later zero stocks cannot look like wholly unfunded
        # growth. Check both a fully funded and a partly funded bunch, and both
        # terminal states, across two subsequent days with zero previous stocks.
        for terminal in (:harvested, :aborted), fraction in (one(T), T(.5))
            case = fixture(T)
            active_days = fraction == one(T) ? 20 : 1
            for _ in 1:active_days
                step!(case; fraction)
            end
            case.st.state = terminal
            case.st.fruits_number = -9999
            st = step!(case)
            @test st.catchup_finalized
            remaining = (st.catchup_outstanding_non_oil_gCH2O,
                st.catchup_outstanding_oil_gCH2O,
                st.catchup_outstanding_stalk_gCH2O)
            scheduled = (st.catchup_scheduled_non_oil_gDM,
                st.catchup_scheduled_oil_gDM, st.catchup_scheduled_stalk_gDM)
            cumulative = (st.catchup_retry_requested_cum_gCH2O,
                st.catchup_effective_requested_cum_gCH2O)
            if fraction == one(T)
                @test all(abs(value) <= tol for value in remaining)
            else
                @test all(value > zero(T) for value in remaining)
            end
            # Emulate BunchHarvest's stock reset after the first terminal day's
            # demand calculation. step! copies these zero stocks into the lag.
            st.biomass_non_oil = zero(T)
            st.biomass_oil = zero(T)
            st.biomass_stalk = zero(T)
            st.biomass_fruits = zero(T)
            st.biomass = zero(T)
            for _ in 1:2
                st = step!(case)
                @test iszero(st.catchup_previous_non_oil_gDM)
                @test iszero(st.catchup_previous_oil_gDM)
                @test iszero(st.catchup_previous_stalk_gDM)
                @test (st.catchup_outstanding_non_oil_gCH2O,
                    st.catchup_outstanding_oil_gCH2O,
                    st.catchup_outstanding_stalk_gCH2O) == remaining
                @test (st.catchup_scheduled_non_oil_gDM,
                    st.catchup_scheduled_oil_gDM,
                    st.catchup_scheduled_stalk_gDM) == scheduled
                @test (st.catchup_retry_requested_cum_gCH2O,
                    st.catchup_effective_requested_cum_gCH2O) == cumulative
                @test iszero(st.carbon_demand)
                @test iszero(st.carbon_demand_non_oil)
                @test iszero(st.carbon_demand_oil)
                @test iszero(st.carbon_demand_stalk)
                @test iszero(st.catchup_new_due_non_oil_gCH2O)
                @test iszero(st.catchup_new_due_oil_gCH2O)
                @test iszero(st.catchup_new_due_stalk_gCH2O)
                @test iszero(st.catchup_retry_requested_gCH2O)
                @test iszero(st.biomass)
            end
            case.st.state = :oleosynthesis
            case.st.fruits_number = 1
            @test_throws ArgumentError step!(case)
        end

        # Previous-step actual biomass must survive real compiled execution:
        # half funding over three identical days yields 2.125 daily increments.
        compiled = fixture(T)
        scene = compiled_scene(compiled)
        @test PSE.Authoring.validate_model(compiled.demand).valid
        @test PSE.Authoring.validate_scenario(scene).valid
        sim = PSE.run!(scene; steps=3, outputs=:none)
        st = PSE.final_state(sim, :bunch)
        @test st.biomass_non_oil ≈ T(2.125 * 5) rtol=tol
        @test st.biomass_oil ≈ T(2.125 * 3.125) rtol=tol
        @test st.biomass_stalk ≈ T(2.125 * 30 * 10 / 42) rtol=tol
        @test st.catchup_scheduled_non_oil_gDM ≈ T(15) rtol=tol
        @test st.catchup_outstanding_non_oil_gCH2O ≈ T(8.75 * 1.44) rtol=tol

        # On the first compiled day, the lag must start from actual configured
        # component stocks rather than silently treating a nonzero organ as empty.
        # Newborn zero defaults bootstrap the temporal binding; they must not
        # replace explicitly configured nonzero stocks in this separate fixture.
        initialized = fixture(T; initial=(T(7), T(3), T(4)),
            targets=(T(10), T(5), T(6)))
        initial_scene = compiled_scene(initialized)
        initial_sim = PSE.run!(initial_scene; steps=1, outputs=:none)
        first_day = PSE.final_state(initial_sim, :bunch)
        @test first_day.catchup_initial_non_oil_gDM ≈ T(7) rtol=tol
        @test first_day.catchup_initial_oil_gDM ≈ T(3) rtol=tol
        @test first_day.catchup_initial_stalk_gDM ≈ T(4) rtol=tol
        @test first_day.biomass_non_oil ≈ T(7.5) rtol=tol
        @test first_day.biomass_oil ≈ T(3.3125) rtol=tol
        @test first_day.biomass_stalk ≈ T(4 + .5 * 6 * 10 / 42) rtol=tol
    end

    # Recovery is the standard model computation, with no parameter flag or
    # exported alternative type. Older parameter dictionaries need no new keys.
    parameters = deepcopy(XPalm.Palm().parameters)
    @test !haskey(parameters["carbon_demand"]["Female"], "catch_up")
    application = XPalm._female_carbon_demand_application(parameters)
    @test application.model isa M.FemaleCarbonDemandModel
    @test application.name == :Female__carbon_demand
    @test length(application.inputs) == 5
    @test !isdefined(M, :CatchUpFemaleCarbonDemandModel)
    for name in (:catchup_previous_non_oil_gDM, :catchup_previous_oil_gDM,
        :catchup_previous_stalk_gDM)
        @test haskey(PSE.inputs_(application.model), name)
    end

    # An obsolete extra key cannot select the former computation. In particular,
    # reading an older experimental file with false still retains missed growth.
    legacy_parameters = deepcopy(parameters)
    legacy_parameters["carbon_demand"]["Female"]["catch_up"] = false
    legacy_application = XPalm._female_carbon_demand_application(legacy_parameters)
    @test legacy_application.model isa M.FemaleCarbonDemandModel
    @test length(legacy_application.inputs) == 5
    obsolete_key_case = merge(fixture(), (; demand=legacy_application.model))
    first_request = step!(obsolete_key_case; supply=0.0).carbon_demand
    @test first_request > 0.0
    second_request = step!(obsolete_key_case; supply=0.0).carbon_demand
    @test second_request ≈ 2first_request

    # Exercise the public XPalm scene compiler and dynamic female emission,
    # rather than checking only application metadata or a synthetic scene.
    public_case = public_female_fixture()
    @test public_case.phytomer.status.sex == :Female
    @test length(PSE.model_objects(public_case.scene; scale=:Female)) == 1
    @test only(app.model for app in public_case.scene.applications
        if app.name == :Female__carbon_demand) isa M.FemaleCarbonDemandModel
    for _ in 1:3
        PSE.continue!(public_case.simulation; steps=1)
        female = only(PSE.model_objects(public_case.scene; scale=:Female))
        st = female.status
        @test st.catchup_initialized
        @test !st.catchup_finalized
        @test all(isfinite, (st.biomass_non_oil, st.biomass_oil, st.biomass_stalk,
            st.carbon_demand, st.catchup_scheduled_non_oil_gDM,
            st.catchup_scheduled_oil_gDM, st.catchup_scheduled_stalk_gDM))
        @test min(st.biomass_non_oil, st.biomass_oil, st.biomass_stalk) >= 0
        @test st.state ∉ (:harvested, :aborted)
    end

    # At unchanged total carbon supply, backlog raises a bunch's competitive
    # share and reduces another sink's allocation; it creates no extra source.
    carbon = fixture()
    step!(carbon; supply=0.0)
    d = carbon.st.carbon_demand
    step!(carbon; supply=0.0)
    dd = carbon.st.carbon_demand
    @test dd ≈ 2d
    alloc = M.OrgansCarbonAllocationModel(; cost_reserve_mobilization=1.667)
    old_allocations = zeros(2)
    new_allocations = zeros(2)
    result_old = M._allocate_organ_carbon!(alloc, [d, d], [0.0, 0.0],
        old_allocations, zeros(2), 40.0)
    result_new = M._allocate_organ_carbon!(alloc, [dd, d], [0.0, 0.0],
        new_allocations, zeros(2), 40.0)
    @test new_allocations[1] > old_allocations[1]
    @test new_allocations[2] < old_allocations[2]
    @test sum(new_allocations) ≈ sum(old_allocations) ≈ 40.0
    @test iszero(result_old.reserve) && iszero(result_new.reserve)

    request = M._catchup_component_request
    @test_throws ArgumentError request(0.0, 0.0, 1.0, 0.0, 1.0, 0.0)
    @test_throws ArgumentError request(0.0, 0.0, -1.0, 0.0, 1.0, 1.44)
    @test_throws ArgumentError request(0.0, 0.0, NaN, 0.0, 1.0, 1.44)
    @test_throws ArgumentError request(-1.0, 0.0, 1.0, 0.0, 1.0, 1.44)
end

end # module
