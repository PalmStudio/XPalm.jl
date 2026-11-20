# Model assertions retain their exception, text and getter evaluation order.
mutable struct XPalmTestEmissionNode
    readings::Vector{Symbol}
    calls::Int
end
function MultiScaleTreeGraph.symbol(node::XPalmTestEmissionNode)
    node.calls += 1
    return node.readings[min(node.calls, length(node.readings))]
end
struct XPalmTestEmissionContext{N}
    node::N
end
PlantSimEngine.source_node(context::XPalmTestEmissionContext) = context.node

@testset "reproductive emission assertion boundaries" begin
    model = ReproductiveOrganEmission(0, 0, :Phytomer, :Male, :Female)
    @test PlantSimEngine.run!(model, (emit_reproductive_organ=false,),
        nothing, nothing, nothing) === nothing
    status = (emit_reproductive_organ=true, sex=:Male, graph_node_count=7)
    node = XPalmTestEmissionNode([:Wrong, :Reported], 0)
    failure = try
        PlantSimEngine.run!(model, status, nothing, nothing, XPalmTestEmissionContext(node))
        nothing
    catch error
        error
    end
    @test failure isa AssertionError
    @test failure.msg == "The function should be applied to a Phytomer, but is applied to a Reported"
    @test node.calls == 2
    @test status.graph_node_count == 7
    node = XPalmTestEmissionNode([:Phytomer], 0)
    status = (emit_reproductive_organ=true, sex=:Unknown, graph_node_count=7)
    failure = try
        PlantSimEngine.run!(model, status, nothing, nothing, XPalmTestEmissionContext(node))
        nothing
    catch error
        error
    end
    @test failure isa AssertionError
    @test failure.msg == "status.sex in (m.male_symbol, m.female_symbol)"
    @test node.calls == 1
    @test status.graph_node_count == 7
end

function xpalm_test_aligned_reserve_allocations(potential, previous, current, offer)
    return @allocated XPalm.Models._fill_organ_reserves!(
        XPalm.Models._aligned_reserve_indices, potential, previous, current, offer)
end

@testset "reserve filling shares its checked and aligned numerical kernel" begin
    for T in (Float32, Float64), offer in (3, T(3))
        potential, previous = T[2, 4], T[1, 3]
        expected, actual = zeros(T, 2), zeros(T, 2)
        checked = @inferred XPalm.Models._fill_organ_reserves!(potential, previous, expected, offer)
        aligned = @inferred XPalm.Models._fill_organ_reserves!(
            XPalm.Models._aligned_reserve_indices, potential, previous, actual, offer)
        @test actual == expected == T[2, 5]
        @test aligned == checked
        @test typeof(aligned) === typeof(checked)
        @test aligned.reserve === T(7)
        @test aligned.carbon_allocation_reserve === T(3)
        @test xpalm_test_aligned_reserve_allocations(potential, previous, actual, offer) == 0
        fill!(potential, zero(T))
        checked = @inferred XPalm.Models._fill_organ_reserves!(potential, previous, expected, offer)
        aligned = @inferred XPalm.Models._fill_organ_reserves!(
            XPalm.Models._aligned_reserve_indices, potential, previous, actual, offer)
        @test actual == expected == previous
        @test aligned == checked
        @test aligned.carbon_allocation_reserve === zero(T)
        @test aligned.carbon_offer_after_storage === T(3)
    end
    for (potential, previous, current, offer) in (
        (Float32[2,4], Float64[1,3], zeros(Float64,2), 3),
        (Float64[2,4], Float32[1,3], zeros(Float32,2), 3.0f0),
    )
        expected = similar(current)
        checked = @inferred XPalm.Models._fill_organ_reserves!(potential, previous, expected, offer)
        aligned = @inferred XPalm.Models._fill_organ_reserves!(
            XPalm.Models._aligned_reserve_indices, potential, previous, current, offer)
        @test current == expected
        @test aligned == checked
        @test typeof(aligned) === typeof(checked)
        @test xpalm_test_aligned_reserve_allocations(potential, previous, current, offer) == 0
    end
    # The existing direct call checks three arrays only in its positive branch.
    current = zeros(2)
    @test_throws DimensionMismatch XPalm.Models._fill_organ_reserves!(ones(3), ones(2), current, 3.0)
    @test current == zeros(2)
    result = XPalm.Models._fill_organ_reserves!(zeros(3), [1.0, 3.0], current, 3.0)
    @test current == [1.0, 3.0]
    @test result.carbon_allocation_reserve == 0.0
    current = zeros(3)
    @test_throws DimensionMismatch XPalm.Models._fill_organ_reserves!(zeros(7), ones(2), current, 3.0)
    @test current == zeros(3)
    empty = Float64[]
    checked = XPalm.Models._fill_organ_reserves!(empty, empty, empty, 3.0)
    aligned = XPalm.Models._fill_organ_reserves!(XPalm.Models._aligned_reserve_indices,
        empty, empty, empty, 3.0)
    @test aligned == checked == (reserve=0.0, carbon_allocation_reserve=0.0,
        carbon_offer_after_storage=3.0)
end

struct XPalmTestOutputTargets{I,C}
    ids::I
    columns::C
end
struct XPalmTestOutputContext{I}
    id::I
end
PlantSimEngine.object_ids(targets::XPalmTestOutputTargets) = targets.ids
PlantSimEngine.object_id(context::XPalmTestOutputContext) = context.id
struct XPalmTestDisplayedId
    value::Int
end
xpalm_test_display_position(io::IO) = position(io)
xpalm_test_display_position(io::IOContext) =
    xpalm_test_display_position(getfield(io, :io))

function Base.show(io::IO, value::XPalmTestDisplayedId)
    # The original ID interpolation starts its own buffer before ObjectId(...).
    print(io, "Shown(", value.value, ",position=", xpalm_test_display_position(io), ")")
end
@testset "distributed output error keeps exact identity rendering" begin
    buffer = IOBuffer()
    write(buffer, "origin:")
    wrapped = IOContext(IOContext(buffer, :compact => true), :limit => true)
    show(wrapped, XPalmTestDisplayedId(9))
    @test String(take!(buffer)) == "origin:Shown(9,position=7)"
    suffix=" as well as its organs so that its plant total is published."
    prefix="XPalm distributed output `reserve` must include the execution plant "
    for raw in (7, :plant, Symbol("a b"), (:tree,:plant,1), (Symbol("a b"),1), XPalmTestDisplayedId(9))
        id=PlantSimEngine.ObjectId(raw)
        targets=XPalmTestOutputTargets([PlantSimEngine.ObjectId(:other)], (reserve=[0.0],))
        expected=prefix*"$(id)"*suffix
        failure=try
            XPalm.Models._organ_output_view(targets,XPalmTestOutputContext(id),Val(:reserve))
            nothing
        catch error
            error
        end
        @test failure isa ArgumentError
        @test failure.msg==expected
        @test targets.columns.reserve==[0.0]
    end
    for plant_index in 1:3
        ids=PlantSimEngine.ObjectId.([1,2,3])
        values=[10.0,20.0,30.0]
        targets=XPalmTestOutputTargets(ids,(reserve=values,))
        view=XPalm.Models._organ_output_view(targets,XPalmTestOutputContext(ids[plant_index]),Val(:reserve))
        @test view.plant_index==plant_index
        @test collect(view.ids)==ids[setdiff(1:3,[plant_index])]
        @test collect(view.values)==values[setdiff(1:3,[plant_index])]
        first_organ=first(setdiff(1:3,[plant_index]));view.values[1]=-7.0
        @test values[first_organ]==-7.0
        @test values[plant_index]==10.0 * plant_index
    end
    id=PlantSimEngine.ObjectId(1)
    targets=XPalmTestOutputTargets([id],(reserve=[1.0],))
    view=XPalm.Models._organ_output_view(targets,XPalmTestOutputContext(id),Val(:reserve))
    @test isempty(view.ids) && isempty(view.values)
end
