"""
    cylinder()
    cylinder(r, l)

Returns a normalized cylinder mesh, or a cylinder with radius `r` and length `l`.

# Arguments

- `r`: The radius of the cylinder.
- `l`: The length of the cylinder.
"""
cylinder() = GeometryBasics.Cylinder(GeometryBasics.Point3(0.0, 0.0, 0.0), GeometryBasics.Point3(0.0, 0.0, 1.0), 1.0)
cylinder(r, l) = GeometryBasics.Cylinder(GeometryBasics.Point3(0.0, 0.0, 0.0), GeometryBasics.Point3(0.0, 0.0, l), r)