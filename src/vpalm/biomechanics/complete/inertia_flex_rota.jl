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
    # Calculate cell size for grid discretization
    cell_size = min(base_width, height) / grid_size
    rows = round(Int, height / cell_size)
    cols = round(Int, base_width / cell_size)

    # Create the section grid based on the section type
    section = zeros(rows, cols)
    section = create_section(section, section_type)

    # Center of gravity calculation
    total_cells = sum(section)

    # Calculate center of gravity using matrix operations
    row_indices = 1:rows
    col_indices = 1:cols
    row_matrix = repeat(row_indices, 1, cols)
    col_matrix = repeat(col_indices', rows, 1)

    center_row = sum(section .* row_matrix) / total_cells
    center_col = sum(section .* col_matrix) / total_cells

    # Create points for cells in the section relative to the center of gravity
    point_type = GeometryBasics.Point{3,typeof(cell_size)}
    section_points = Vector{point_type}()

    zero_length = zero(eltype(base_width))
    for row in 1:rows, col in 1:cols
        if section[row, col] > 0
            # Calculate position relative to center of mass
            x = (col - center_col) * cell_size
            y = (row - center_row) * cell_size
            z = zero_length
            push!(section_points, point_type(x, y, z))
        end
    end

    # Apply section orientation rotation.
    rotation = RotZ(orientation_angle)
    rotated_points = [rotation * GeometryBasics.Vec{3,typeof(cell_size)}(p[1], p[2], p[3]) for p in section_points]

    # Calculate inertias using efficient vector operations
    cell_area = cell_size^2

    # Extract coordinates from rotated points
    x_coords = [p[1] for p in rotated_points]
    y_coords = [p[2] for p in rotated_points]

    # Calculate inertias and cross-section area
    bending_inertia = sum(y_coords .^ 2) * cell_area
    torsion_inertia = sum(x_coords .^ 2 .+ y_coords .^ 2) * cell_area
    section_area = length(section_points) * cell_area

    return (ig_flex=bending_inertia, ig_tor=torsion_inertia, sr=section_area)
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
