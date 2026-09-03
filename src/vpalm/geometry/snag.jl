"""
    snag()
    snag(l, w, h)

Returns a snag mesh rebuilt procedurally from the original Java 3-segment shape.
The normalized version spans `x ∈ [0, 1]`, `y ∈ [-0.5, 0.5]`, `z ∈ [-0.5, 0.5]`.
"""
const SNAG_SEGMENT_LENGTHS = (5.0, 5.0, 3.0)
const SNAG_TOTAL_LENGTH = sum(SNAG_SEGMENT_LENGTHS)
const SNAG_PATH = GeometryBasics.Point{3,Float64}[
    GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0),
    GeometryBasics.Point{3,Float64}(SNAG_SEGMENT_LENGTHS[1] / SNAG_TOTAL_LENGTH, 0.0, 0.0),
    GeometryBasics.Point{3,Float64}(sum(SNAG_SEGMENT_LENGTHS[1:2]) / SNAG_TOTAL_LENGTH, 0.0, 0.0),
    GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0),
]
const SNAG_WIDTHS = (1.0, 13.0 / 30.0, 11.0 / 30.0, 0.0)
const SNAG_HEIGHTS = (1.0, 9.0 / 10.0, 7.0 / 10.0, 0.0)
const SNAG_N_SIDES = 6

function snag_geometry(; transformation=PlantGeom.IdentityTransformation())
    PlantGeom.ExtrudedTubeGeometry(
        SNAG_PATH;
        n_sides=SNAG_N_SIDES,
        widths=SNAG_WIDTHS,
        heights=SNAG_HEIGHTS,
        torsion=true,
        cap_ends=true,
        transformation=transformation,
    )
end

snag() = PlantGeom.extrude_tube_mesh(
    SNAG_PATH;
    n_sides=SNAG_N_SIDES,
    widths=SNAG_WIDTHS,
    heights=SNAG_HEIGHTS,
    torsion=true,
    cap_ends=true,
)

const SNAG = snag()

function snag(l, w, h)
    scaled_path = [GeometryBasics.Point{3,Float64}(p[1] * l, p[2], p[3]) for p in SNAG_PATH]
    PlantGeom.extrude_tube_mesh(
        scaled_path;
        n_sides=SNAG_N_SIDES,
        widths=map(x -> x * w, SNAG_WIDTHS),
        heights=map(x -> x * h, SNAG_HEIGHTS),
        torsion=true,
        cap_ends=true,
    )
end
