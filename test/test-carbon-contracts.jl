struct FarquharAssimilationRateSource <:
       XPalm.Models.AbstractCarbon_AssimilationModel end

PlantSimEngine.inputs_(::FarquharAssimilationRateSource) = NamedTuple()
PlantSimEngine.outputs_(::FarquharAssimilationRateSource) = (
    carbon_assimilation=1.0,
)
PlantSimEngine.variable_contracts_(::FarquharAssimilationRateSource) = (
    carbon_assimilation=PlantSimEngine.VariableContract(
        unit=:micromol_co2,
        basis=:leaf_area,
        temporal=:second,
        aggregation=:rate,
        extent=:intensive,
    ),
)

function PlantSimEngine.run!(
    ::FarquharAssimilationRateSource,
    status,
    environment,
    constants,
    context=nothing,
)
    status.carbon_assimilation = 1.0
    return nothing
end

@testset "canonical CH2O-equivalent currency" begin
    daily_ch2o = PlantSimEngine.VariableContract(
        unit=:g_ch2o_equivalent,
        basis=:object,
        temporal=:day,
        aggregation=:total,
        extent=:extensive,
    )
    ch2o_stock = PlantSimEngine.VariableContract(
        unit=:g_ch2o_equivalent,
        basis=:object,
        aggregation=:state,
        extent=:extensive,
    )
    structural_dry_mass = PlantSimEngine.VariableContract(
        unit=:g_dry_matter,
        basis=:object,
        aggregation=:state,
        extent=:extensive,
    )
    fresh_mass = PlantSimEngine.VariableContract(
        unit=:kg_fresh_matter,
        basis=:object,
        aggregation=:state,
        extent=:extensive,
    )

    @test PlantSimEngine.variable_contracts(
        ConstantRUEModel(4.8),
    ).carbon_assimilation == daily_ch2o

    offer_contracts = PlantSimEngine.variable_contracts(CarbonOfferRm())
    @test offer_contracts.carbon_assimilation == daily_ch2o
    @test offer_contracts.Rm == daily_ch2o
    @test offer_contracts.carbon_offer_after_rm == daily_ch2o

    allocation_contracts = PlantSimEngine.variable_contracts(
        OrgansCarbonAllocationModel(),
    )
    @test allocation_contracts.carbon_offer_after_rm == daily_ch2o
    @test allocation_contracts.carbon_demand_organs == daily_ch2o
    @test allocation_contracts.carbon_allocation == daily_ch2o
    @test allocation_contracts.previous_reserve_organs == ch2o_stock
    @test allocation_contracts.reserve == ch2o_stock

    respiration_contracts = PlantSimEngine.variable_contracts(
        RmQ10FixedN(2.0, 0.0083, 25.0, 1.0),
    )
    @test respiration_contracts.biomass == structural_dry_mass
    @test respiration_contracts.Rm == daily_ch2o

    fresh_biomass_contracts = PlantSimEngine.variable_contracts(
        VPalm.LeafFreshBiomass(
            leaflets_dry_matter_fraction=0.430,
            rachis_dry_matter_fraction=0.308,
            petiole_dry_matter_fraction=0.273,
        ),
    )
    @test fresh_biomass_contracts.biomass_leaflets == structural_dry_mass
    @test fresh_biomass_contracts.biomass_rachis == structural_dry_mass
    @test fresh_biomass_contracts.biomass_petiole == structural_dry_mass
    @test fresh_biomass_contracts.reserve == ch2o_stock
    @test fresh_biomass_contracts.fresh_biomass_leaflets == fresh_mass
    @test fresh_biomass_contracts.fresh_biomass_rachis == fresh_mass
    @test fresh_biomass_contracts.fresh_biomass_petiole == fresh_mass

    incompatible = CompositeModel(
        Object(
            :plant;
            scale=:Plant,
            kind=:plant,
            status=Status(Rm=0.0),
        );
        applications=(
            ModelSpec(
                FarquharAssimilationRateSource();
                name=:farquhar_rate_source,
                on=One(scale=:Plant),
            ),
            ModelSpec(
                CarbonOfferRm();
                name=:carbon_offer,
                on=One(scale=:Plant),
            ),
        ),
        environment=(duration=Day(1),),
    )
    exception = try
        PlantSimEngine.Advanced.refresh_bindings!(incompatible)
        nothing
    catch error
        error
    end
    @test exception isa ErrorException
    if exception isa Exception
        message = sprint(showerror, exception)
        @test occursin("Incompatible variable contracts", message)
        @test occursin(
            "unit producer=:micromol_co2, consumer=:g_ch2o_equivalent",
            message,
        )
        @test occursin("basis producer=:leaf_area, consumer=:object", message)
        @test occursin("temporal producer=:second, consumer=:day", message)
        @test occursin("aggregation producer=:rate, consumer=:total", message)
        @test occursin("Rename or convert the variable", message)
    end
end
