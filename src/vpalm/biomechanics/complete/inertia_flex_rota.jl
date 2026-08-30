"""
    inertia_flex_rota(base_width, height, orientation_angle, section_type, grid_size = 100)

Compute the inertia of bending and torsion, and the cross-section area.

# Arguments
- `base_width`: Dimension of the base.
- `height`: Dimension of the height.
- `orientation_angle`: Section orientation angle (torsion, in radians).
- `section_type`: Section type (see details).
- `grid_size`: Number of discretizations (default to 100).

# Details

For the section type, possible values are:
- `section_type = 1`: triangle (bottom-oriented)
- `section_type = 2`: rectangle
- `section_type = 3`: triangle (top-oriented)
- `section_type = 4`: ellipse
- `section_type = 5`: circle

# Returns

- A NamedTuple with fields:
  - `ig_flex`: Bending inertia.
  - `ig_tor`: Torsion inertia.
  - `sr`: Cross-section surface.
"""
function inertia_flex_rota(base_width, height, orientation_angle, section_type, grid_size=100)
    moments = _section_grid_moments(base_width, height, section_type, grid_size)
    return _rotate_section_moments(moments, orientation_angle)
end

"""
    _section_grid_moments(base_width, height, section_type, grid_size)

Compute the unrotated second moments and area of a rasterized section without
materializing its grid or its cell-center points. The membership predicates are
kept identical to [`create_section`](@ref), so this is a numerical optimization
of the historical discretization rather than a change to the section model.
"""
function _section_grid_moments(base_width, height, section_type, grid_size=100)
    cell_size = min(base_width, height) / grid_size
    rows = round(Int, height / cell_size)
    cols = round(Int, base_width / cell_size)

    total_cells = 0
    sum_row = 0.0
    sum_col = 0.0
    sum_row_squared = 0.0
    sum_col_squared = 0.0
    sum_row_col = 0.0

    if section_type == 1
        b13 = [1 1; cols / 2 1] \ [1; rows]
        b23 = [cols 1; cols / 2 1] \ [1; rows]

        for row in 1:rows, col in 1:cols
            n13 = col * b13[1] + b13[2]
            n23 = col * b23[1] + b23[2]
            if row <= n13 && row <= n23
                total_cells += 1
                sum_row += row
                sum_col += col
                sum_row_squared += row^2
                sum_col_squared += col^2
                sum_row_col += row * col
            end
        end
    elseif section_type == 2
        for row in 1:rows, col in 1:cols
            total_cells += 1
            sum_row += row
            sum_col += col
            sum_row_squared += row^2
            sum_col_squared += col^2
            sum_row_col += row * col
        end
    elseif section_type == 3
        b13 = [1 1; cols / 2 1] \ [rows; 1]
        b23 = [cols 1; cols / 2 1] \ [rows; 1]

        for row in 1:rows, col in 1:cols
            n13 = col * b13[1] + b13[2]
            n23 = col * b23[1] + b23[2]
            if row >= n13 && row >= n23
                total_cells += 1
                sum_row += row
                sum_col += col
                sum_row_squared += row^2
                sum_col_squared += col^2
                sum_row_col += row * col
            end
        end
    elseif section_type == 4
        a = max(rows, cols) / 2
        b = min(rows, cols) / 2
        c = sqrt(a^2 - b^2)

        if rows >= cols
            col_center = cols / 2
            focal_point1 = a - c
            focal_point2 = 2 * c + (a - c)

            for row in 1:rows, col in 1:cols
                dist1 = sqrt((row - focal_point1)^2 + (col - col_center)^2)
                dist2 = sqrt((row - focal_point2)^2 + (col - col_center)^2)
                if dist1 + dist2 <= 2a
                    total_cells += 1
                    sum_row += row
                    sum_col += col
                    sum_row_squared += row^2
                    sum_col_squared += col^2
                    sum_row_col += row * col
                end
            end
        else
            row_center = rows / 2
            focal_point1 = a - c
            focal_point2 = 2 * c + (a - c)

            for row in 1:rows, col in 1:cols
                dist1 = sqrt((row - row_center)^2 + (col - focal_point1)^2)
                dist2 = sqrt((row - row_center)^2 + (col - focal_point2)^2)
                if dist1 + dist2 <= 2a
                    total_cells += 1
                    sum_row += row
                    sum_col += col
                    sum_row_squared += row^2
                    sum_col_squared += col^2
                    sum_row_col += row * col
                end
            end
        end
    elseif section_type == 5
        radius = min(rows, cols) / 2
        row_center = rows / 2
        col_center = cols / 2

        for row in 1:rows, col in 1:cols
            dist = sqrt((row - row_center)^2 + (col - col_center)^2)
            if dist <= radius
                total_cells += 1
                sum_row += row
                sum_col += col
                sum_row_squared += row^2
                sum_col_squared += col^2
                sum_row_col += row * col
            end
        end
    end

    cell_area = cell_size^2
    cell_inertia = cell_size^4
    if total_cells == 0
        zero_inertia = zero(cell_inertia)
        return (
            ig_x=zero_inertia,
            ig_y=zero_inertia,
            ig_xy=zero_inertia,
            ig_tor=zero_inertia,
            sr=zero(cell_area),
        )
    end

    centered_row_squared = sum_row_squared - sum_row^2 / total_cells
    centered_col_squared = sum_col_squared - sum_col^2 / total_cells
    centered_row_col = sum_row_col - sum_row * sum_col / total_cells

    ig_x = centered_row_squared * cell_inertia
    ig_y = centered_col_squared * cell_inertia
    ig_xy = centered_row_col * cell_inertia

    return (
        ig_x=ig_x,
        ig_y=ig_y,
        ig_xy=ig_xy,
        ig_tor=ig_x + ig_y,
        sr=total_cells * cell_area,
    )
end

@inline function _rotate_section_moments(moments, orientation_angle)
    sine, cosine = sincos(orientation_angle)
    bending_inertia =
        moments.ig_x * cosine^2 +
        moments.ig_y * sine^2 +
        2 * moments.ig_xy * sine * cosine

    return (ig_flex=bending_inertia, ig_tor=moments.ig_tor, sr=moments.sr)
end

"""
    create_section(section, section_type)

Fill in the matrix according to the section shape.

# Arguments
- `section`: Section matrix.
- `section_type`: Section type (1: triangle bottom, 2: rectangle, 3: triangle top, 4: ellipse, 5: circle).

# Returns
- The filled section matrix with 1s for cells inside the shape and 0s outside.
"""
function create_section(section, section_type)
    rows, cols = size(section)

    # Create index matrices once (efficient for all section types)
    row_indices = 1:rows
    col_indices = 1:cols
    row_matrix = repeat(row_indices, 1, cols)
    col_matrix = repeat(col_indices', rows, 1)

    # section_type = 1: triangle (bottom-oriented)
    if section_type == 1
        b13 = [1 1; cols/2 1] \ [1; rows]
        b23 = [cols 1; cols/2 1] \ [1; rows]

        n13 = col_matrix * b13[1] .+ b13[2]
        n23 = col_matrix * b23[1] .+ b23[2]

        section = (row_matrix .<= n13) .& (row_matrix .<= n23)

        # section_type = 2: rectangle
    elseif section_type == 2
        section = ones(Bool, size(section))

        # section_type = 3: triangle (top-oriented)
    elseif section_type == 3
        b13 = [1 1; cols/2 1] \ [rows; 1]
        b23 = [cols 1; cols/2 1] \ [rows; 1]

        n13 = col_matrix * b13[1] .+ b13[2]
        n23 = col_matrix * b23[1] .+ b23[2]

        section = (row_matrix .>= n13) .& (row_matrix .>= n23)

        # section_type = 4: ellipse
    elseif section_type == 4
        a = maximum(size(section)) / 2
        b = minimum(size(section)) / 2
        c = sqrt(a^2 - b^2)

        if rows >= cols
            # Ellipse with major axis in the vertical direction
            col_center = cols / 2

            focal_point1 = (a - c)
            focal_point2 = 2 * c + (a - c)

            dist1 = sqrt.((row_matrix .- focal_point1) .^ 2 .+ (col_matrix .- col_center) .^ 2)
            dist2 = sqrt.((row_matrix .- focal_point2) .^ 2 .+ (col_matrix .- col_center) .^ 2)

            section = ((dist1 .+ dist2) .<= (2 * a))
        else
            # Ellipse with major axis in the horizontal direction
            row_center = rows / 2

            focal_point1 = (a - c)
            focal_point2 = 2 * c + (a - c)

            dist1 = sqrt.((row_matrix .- row_center) .^ 2 .+ (col_matrix .- focal_point1) .^ 2)
            dist2 = sqrt.((row_matrix .- row_center) .^ 2 .+ (col_matrix .- focal_point2) .^ 2)

            section = ((dist1 .+ dist2) .<= (2 * a))
        end

        # section_type = 5: circle
    elseif section_type == 5
        radius = minimum(size(section)) / 2

        row_center = rows / 2
        col_center = cols / 2

        dist = sqrt.((row_matrix .- row_center) .^ 2 .+ (col_matrix .- col_center) .^ 2)
        section = dist .<= radius
    end

    return section
end
