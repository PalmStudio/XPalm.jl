"""
    read_ply(fname)

Reads a PLY file and returns a `Meshes.SimpleMesh` object.

# Arguments

- `fname`: The path to the PLY file.

# Returns

A `Meshes.SimpleMesh` object.
"""
function read_ply(fname)
    ply = PlyIO.load_ply(fname)
    x = ply["vertex"]["x"]
    y = ply["vertex"]["y"]
    z = ply["vertex"]["z"]
    points = Meshes.Point.(x, y, z)
    connec = [Meshes.connect(Tuple(c .+ 1)) for c in ply["face"]["vertex_indices"]]
    Meshes.SimpleMesh(points, connec)
end