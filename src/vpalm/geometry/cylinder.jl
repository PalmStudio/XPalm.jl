"""
    cylinder()
    cylinder(r, l)

Returns a normalized cylinder mesh, or a cylinder with radius `r` and length `l`.

# Arguments

- `r`: The radius of the cylinder.
- `l`: The length of the cylinder.
"""
cylinder() = Meshes.CylinderSurface(1.0) |> Meshes.discretize |> Meshes.simplexify
cylinder(r, l) = Meshes.CylinderSurface(Meshes.Point(0.0, 0.0, 0.0), Meshes.Point(0.0, 0.0, l), r) |> Meshes.discretize |> Meshes.simplexify


"""
    elliptical_cylinder(r1, r2, l)

Create an elliptical cylinder mesh.

# Arguments

- `r1`: The radius of the cylinder in the x direction.
- `r2`: The radius of the cylinder in the y direction.
- `l`: The length of the cylinder.
"""
function elliptical_cylinder(r1, r2, l)
    # uses the cylinder, and then scales the x and y directions
    return cylinder(1.0, l) |> Meshes.Scale(r1, r2, 1.0)
end