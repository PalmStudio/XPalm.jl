"""
    create_plane_mesh()

Create a simple rectangular plane mesh that will be used as a reference for leaflet segments.
The plane is created in the XZ plane with width along X and length along Z.

# Returns

A `GeometryBasics.Mesh` object representing a simple rectangular plane mesh
"""
function plane()
    # Create a simple rectangle in the XZ plane
    # With vertices at corners, centered at origin
    vertices = [
        GeometryBasics.Point3(0.0, 0.0, -0.5),  # Left bottom
        GeometryBasics.Point3(1.0, 0.0, -0.5),   # Right bottom
        GeometryBasics.Point3(1.0, 0.0, 0.5),   # Right top
        GeometryBasics.Point3(0.0, 0.0, 0.5)   # Left top
    ]

    # Create triangular faces
    # Two triangles to form the rectangle
    faces = [
        GeometryBasics.TriangleFace((1, 2, 3)),
        GeometryBasics.TriangleFace((1, 3, 4))
    ]

    # Create the mesh
    return GeometryBasics.Mesh(vertices, faces)
end
