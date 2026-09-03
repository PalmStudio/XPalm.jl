function _legacy_inertia_flex_rota(base_width, height, orientation_angle, section_type, grid_size=100)
    cell_size = min(base_width, height) / grid_size
    rows = round(Int, height / cell_size)
    cols = round(Int, base_width / cell_size)

    section = VPalm.create_section(zeros(rows, cols), section_type)
    total_cells = sum(section)
    row_matrix = repeat(1:rows, 1, cols)
    col_matrix = repeat((1:cols)', rows, 1)
    center_row = sum(section .* row_matrix) / total_cells
    center_col = sum(section .* col_matrix) / total_cells

    point_type = GeometryBasics.Point{3,typeof(cell_size)}
    section_points = Vector{point_type}()
    zero_length = zero(eltype(base_width))
    for row in 1:rows, col in 1:cols
        if section[row, col] > 0
            push!(
                section_points,
                point_type(
                    (col - center_col) * cell_size,
                    (row - center_row) * cell_size,
                    zero_length,
                ),
            )
        end
    end

    rotation = VPalm.RotZ(orientation_angle)
    rotated_points = [
        rotation * GeometryBasics.Vec{3,typeof(cell_size)}(point[1], point[2], point[3])
        for point in section_points
    ]
    cell_area = cell_size^2
    x_coords = [point[1] for point in rotated_points]
    y_coords = [point[2] for point in rotated_points]

    return (
        ig_flex=sum(y_coords .^ 2) * cell_area,
        ig_tor=sum(x_coords .^ 2 .+ y_coords .^ 2) * cell_area,
        sr=length(section_points) * cell_area,
    )
end

function _warmed_inertia_allocations()
    for section_type in 1:5
        VPalm.inertia_flex_rota(0.20u"m", 0.10u"m", 0.37, section_type, 100)
    end

    return @allocated begin
        for section_type in 1:5
            VPalm.inertia_flex_rota(0.20u"m", 0.10u"m", 0.37, section_type, 100)
        end
    end
end

@testset "inertia_flex_rota works" begin
    width_bend = 0.20u"m"
    height_bend = 0.10u"m"
    type_val = 1
    npoints = 100

    expected = (
        (ig_flex=5.556355779422049e-6u"m^4", ig_tor=2.2231354779522046e-5u"m^4", sr=0.010001u"m^2"),
        (ig_flex=1.3603727582400172e-5u"m^4", ig_tor=2.2231354779522046e-5u"m^4", sr=0.010001u"m^2"),
        (ig_flex=1.444533970624659e-5u"m^4", ig_tor=2.2231354779522042e-5u"m^4", sr=0.010001u"m^2"),
    )

    for (orientation_angle, reference) in zip((0.0, 45.0, 90.0), expected)
        result = VPalm.inertia_flex_rota(width_bend, height_bend, orientation_angle, type_val, npoints)
        @test result.ig_flex ≈ reference.ig_flex rtol = 1e-12
        @test result.ig_tor ≈ reference.ig_tor rtol = 1e-12
        @test result.sr == reference.sr
    end
end

@testset "raw section moments preserve the raster calculation" begin
    dimensions = ((0.20u"m", 0.10u"m"), (0.083u"m", 0.127u"m"))
    for (width, height) in dimensions,
        section_type in 1:5,
        orientation_angle in (0.0, 0.37, pi / 2)

        reference = _legacy_inertia_flex_rota(width, height, orientation_angle, section_type, 100)
        result = VPalm.inertia_flex_rota(width, height, orientation_angle, section_type, 100)

        @test result.ig_flex ≈ reference.ig_flex rtol = 1e-12
        @test result.ig_tor ≈ reference.ig_tor rtol = 1e-12
        @test result.sr == reference.sr
    end
end

@testset "section inertia invariants" begin
    width = 0.20u"m"
    height = 0.10u"m"
    scale = 3.0

    for section_type in 1:5
        unrotated = VPalm.inertia_flex_rota(width, height, 0.0, section_type, 100)
        rotated = VPalm.inertia_flex_rota(width, height, 0.73, section_type, 100)
        half_turn = VPalm.inertia_flex_rota(width, height, pi, section_type, 100)
        scaled = VPalm.inertia_flex_rota(scale * width, scale * height, 0.73, section_type, 100)

        @test rotated.ig_tor == unrotated.ig_tor
        @test rotated.sr == unrotated.sr
        @test half_turn.ig_flex ≈ unrotated.ig_flex rtol = 1e-13
        @test scaled.ig_flex ≈ scale^4 * rotated.ig_flex rtol = 1e-13
        @test scaled.ig_tor ≈ scale^4 * rotated.ig_tor rtol = 1e-13
        @test scaled.sr ≈ scale^2 * rotated.sr rtol = 1e-13
    end
end

@testset "section inertia allocation regression" begin
    # Function-scoped warmup avoids top-level @allocated measurement artifacts.
    @test _warmed_inertia_allocations() <= 64 * 1024
end
