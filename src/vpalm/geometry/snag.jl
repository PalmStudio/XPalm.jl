"""
    snag()
    snag(l, w, h)


Returns a normalized snag mesh, or a snag mesh with given dimensions in m.
"""
function snag()
    read_ply(joinpath(@__DIR__, "..", "..", "./assets/snag.ply"))
end

const SNAG = snag()

function snag(l, w, h)
    SNAG |> Meshes.Scale(l, w, h)
end