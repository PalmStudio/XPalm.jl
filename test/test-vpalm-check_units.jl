@testset "check_unit macro" begin
    # Test case 1: Adding units to a variable without units
    length_no_unit = 10.0
    length_with_unit = VPalm.@check_unit length_no_unit u"m" false
    @test unit(length_with_unit) == u"m"
    @test length_with_unit == 10.0u"m"

    # Test case 2: Variable already has the expected unit
    mass_in_kg = 2.5u"kg"
    mass_checked = VPalm.@check_unit mass_in_kg u"kg"
    @test mass_checked == mass_in_kg
    @test unit(mass_checked) == u"kg"

    # Test case 3: Converting from one unit to another
    distance_in_cm = 150.0u"cm"
    distance_in_m = VPalm.@check_unit distance_in_cm u"m"
    @test unit(distance_in_m) == u"m"
    @test distance_in_m ≈ 1.5u"m"

    # Test case 4: Converting between different unit types (mass to length should fail)
    weight_in_g = 200.0u"g"
    @test_throws ErrorException VPalm.@check_unit weight_in_g u"m"

    # Test case 5: Test with dimensionless integers (radians are dimensionless)
    count = 5
    count_with_unit = VPalm.@check_unit count u"rad" false
    @test count_with_unit == 5
    @test unit(count_with_unit) == u"rad"

    # Test case 6: Test with angles
    angle_no_unit = 45
    angle_with_unit = VPalm.@check_unit angle_no_unit u"°" false
    @test unit(angle_with_unit) == u"°"
    @test angle_with_unit == 45u"°"

    # Test case 7: Test angle conversion
    angle_in_rad = π / 4 * u"rad"
    angle_in_deg = VPalm.@check_unit angle_in_rad u"°"
    @test unit(angle_in_deg) == u"°"
    @test isapprox(angle_in_deg.val, 45.0, atol=1e-10)

    # Test case 8: With arrays (should work element-wise)
    lengths = [10.0, 20.0, 30.0]
    lengths_with_unit = [VPalm.@check_unit l u"m" false for l in lengths]
    @test all(unit.(lengths_with_unit) .== u"m")
    @test lengths_with_unit == [10.0u"m", 20.0u"m", 30.0u"m"]
end