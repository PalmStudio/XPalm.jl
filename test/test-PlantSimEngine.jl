using PlantMeteo, PlantSimEngine
using DataFrames, CSV
using XPalm

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
meteo.T = meteo.Taverage
meteo.Rh .= (meteo.Rh_max .- meteo.Rh_min) ./ 2 ./ 100
m = Weather(meteo)

p = Palm(nsteps=nrow(m))
mapping = Dict(
    "Plant" => (
        MultiScaleModel(
            model=XPalm.OrgansCarbonAllocationModel(p.parameters[:carbon_demand][:reserves][:cost_reserve_mobilization]),
            mapping=[
                PreviousTimeStep(:reserve_organs) => ["Leaf" .=> :reserve],
                PreviousTimeStep(:reserve),
            ]
        ),
        MultiScaleModel(
            model=XPalm.OrganReserveFilling(),
            mapping=[
                :potential_reserve_organs => ["Leaf"] .=> :potential_reserve,
                :reserve_organs => ["Leaf"] .=> :reserve,
            ],
        ),
        Status(carbon_demand_organs=[10.0], carbon_offer_after_rm=12.0, potential_reserve_organs=[2.0])
    ),
    "Leaf" => (
        MultiScaleModel(
            model=XPalm.PotentialReserveLeaf(
                p.parameters[:lma_min],
                p.parameters[:lma_max],
                p.parameters[:leaflets_biomass_contribution]
            ),
            mapping=[PreviousTimeStep(:leaf_area), PreviousTimeStep(:reserve)],
        ),
        Status(leaf_area=1.0, reserve=2.0)
    ),
)

d = dep(mapping)

@testset "PlantSimEngine PreviousTimeStep flag" begin
    #* In this mapping we have one variable (reserve_organs) that is flagged as PreviousTimeStep in a model (OrgansCarbonAllocationModel), 
    #* and used at the current time-step in another model as an output of the model (OrganReserveFilling), both at the same scale.
    # Testing that the variables flagged as PreviousTimeStep are correctly linked to the previous time step:
    @test d.roots["Plant"=>:carbon_allocation].inputs[1].second.reserve_organs.variable == PreviousTimeStep(:reserve_organs, :carbon_allocation)
    @test d.roots["Plant"=>:carbon_allocation].inputs[1].second.reserve.variable == PreviousTimeStep(:reserve, :carbon_allocation)

    @test d.roots["Plant"=>:carbon_allocation].children[1].inputs[1].second.potential_reserve_organs.variable == :potential_reserve_organs
    # This variable is an output (so at the current time step) for the XPalm.OrganReserveFilling, so it is not flagged as PreviousTimeStep as for the XPalm.OrgansCarbonAllocationModel model above:
    @test d.roots["Plant"=>:carbon_allocation].children[1].outputs[1].second.reserve_organs.variable == :reserve_organs
    @test d.roots["Plant"=>:carbon_allocation].children[1].outputs[1].second.reserve == 0.0
end


