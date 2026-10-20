# Direct-kernel hard-call boundary: execute the unchanged native root model on
# this status, without reaching into PlantSimEngine's compiled internals.
struct BPRechargeKernelContext{R,S,E,C}
    roots::R
    status::S
    environment::E
    constants::C
    calls::Base.RefValue{Int}
end

function PlantSimEngine.run_call!(context::BPRechargeKernelContext,
    process::Symbol; publish=false, kwargs...)
    process == :root_growth || error("Unexpected recharge-test call: $process")
    PlantSimEngine.run!(context.roots, context.status, context.environment,
        context.constants, nothing)
    context.calls[] += 1
    return nothing
end

bp_bulk_water(status) = status.qty_H2O_Vap + status.qty_H2O_C1minusVap + status.qty_H2O_C2
bp_root_water(status) = status.qty_H2O_Vap_Roots +
    status.qty_H2O_C1minusVap_Roots + status.qty_H2O_C2_Roots

function bp_recharge_status(model, T)
    values = merge(PlantSimEngine.outputs_(model),
        (root_depth=model.ini_root_depth, ET0=0.0, TEff=0.0,
         aPPFD=10.0 * PlantSimEngine.Constants().J_to_umol))
    status = Status(map(value -> value isa AbstractFloat ? T(value) : value, values))
    XPalm.Models.compute_compartment_size(model, status)
    XPalm.Models.compute_fraction_bp!(status)
    return status
end

function bp_recharge_step!(model, status, rain)
    environment = (Ri_PAR_f=10.0, Precipitations=rain, duration=Day(1))
    context = BPRechargeKernelContext(
        RootGrowthFTSW(ini_root_depth=model.ini_root_depth),
        status, environment, PlantSimEngine.Constants(), Ref(0),
    )
    PlantSimEngine.run!(model, status, environment, context.constants, context)
    @test context.calls[] == 1
    return nothing
end

@testset "Effective rainfall recharges the rooted soil view" begin
    # Zero TEff fixes root depth and zero ET isolates infiltration. Test roots
    # within and below the 200-mm top layer, light rain, overflow and dry days.
    # Bulk and rooted stocks overlap; their inventories are never summed.
    for T in (Float32, Float64), depth in (100.0, 300.0)
        model = FTSW_BP(ini_root_depth=depth, H_0=0.10)
        status = bp_recharge_status(model, T)
        tolerance = T == Float32 ? 2e-5 : 1e-10
        for rain in (0.0, 5.0, 1.0, 0.0, 100.0, 0.0)
            before_bulk = bp_bulk_water(status)
            before_root = bp_root_water(status)
            bp_recharge_step!(model, status, rain)
            bulk_capacity = status.SizeVap + status.SizeC1minusVap + status.SizeC2
            root_capacity = status.roots_SizeVap +
                status.roots_SizeC1minusVap + status.roots_SizeC2
            bulk_drainage = max(0.0, before_bulk + status.rain_effective - bulk_capacity)
            root_drainage = max(0.0, before_root + status.rain_effective - root_capacity)
            @test bp_bulk_water(status) - before_bulk + bulk_drainage ≈
                  status.rain_effective atol=tolerance
            @test bp_root_water(status) - before_root + root_drainage ≈
                  status.rain_effective atol=tolerance
            @test status.rain_remain ≈ root_drainage atol=tolerance
            @test status.root_depth == depth
            @test 0 <= status.ftsw <= 1 + tolerance
        end

        # A dry-down with full canopy cover has no evaporation. Whatever
        # actual transpiration is extracted must leave both overlapping views.
        # Restrict this additional extraction check to roots at/below Z1, as
        # in the archived recharge audit: above Z1, native bulk/root capacities
        # partition their evaporative/transpirable stocks inconsistently. Once
        # bulk transpirable water is exhausted, that separate legacy defect
        # invalidates the extraction equality. The rain-only checks above still
        # exercise shallow roots; this PR does not redesign their capacities.
        if depth >= model.Z1
            status.ET0 = T(2.5)
            for day in 1:40
                before_bulk = bp_bulk_water(status)
                before_root = bp_root_water(status)
                bp_recharge_step!(model, status, 0.0)
                actual_extraction = before_root - bp_root_water(status)
                @test before_bulk - bp_bulk_water(status) ≈ actual_extraction atol=tolerance
                @test -tolerance <= actual_extraction <= status.transpiration + tolerance
            end
        end
    end
end

@testset "Rooted rainfall recharge in a compiled soil scenario" begin
    model = FTSW_BP(ini_root_depth=300.0, H_0=0.10)
    before = model.ini_qty_H2O_Vap_Roots + model.ini_qty_H2O_C1minusVap_Roots +
        model.ini_qty_H2O_C2_Roots
    scene = CompositeModel(
        Object(:soil; scale=:Soil, kind=:soil,
            status=Status(ET0=0.0, TEff=0.0,
                aPPFD=10.0 * PlantSimEngine.Constants().J_to_umol,
                ftsw=model.ini_ftsw, soil_depth=model.soil_depth));
        applications=(
            ModelSpec(RootGrowthFTSW(ini_root_depth=300.0);
                name=:root_growth, on=One(scale=:Soil)),
            ModelSpec(model; name=:soil_water, on=One(scale=:Soil)),
        ),
        environment=(Ri_PAR_f=10.0, Precipitations=5.0, duration=Day(1)),
    )
    run!(scene; steps=1, outputs=:none)
    status = only(model_objects(scene; scale=:Soil)).status
    @test bp_root_water(status) - before ≈ status.rain_effective
    @test bp_root_water(status) ≈ bp_bulk_water(status)
end
