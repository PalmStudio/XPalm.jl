"""
    create_plane_mesh()

Create a simple rectangular plane mesh that will be used as a reference for leaflet segments.
The plane is created in the XZ plane with width along X and length along Z.

# Returns

A Meshes.SimpleMesh object representing a simple rectangular plane mesh
"""
function plane()
    # Create a simple rectangle in the XZ plane
    # With vertices at corners, centered at origin
    vertices = [
        Meshes.Point(0.0, 0.0, -0.5),  # Left bottom
        Meshes.Point(1.0, 0.0, -0.5),   # Right bottom
        Meshes.Point(1.0, 0.0, 0.5),   # Right top
        Meshes.Point(0.0, 0.0, 0.5)   # Left top
    ]

    # Create triangular faces
    # Two triangles to form the rectangle
    faces = [
        Meshes.connect((1, 2, 3), Meshes.Triangle),
        Meshes.connect((1, 3, 4), Meshes.Triangle)
    ]

    # Create the mesh
    return Meshes.SimpleMesh(vertices, faces)
end
