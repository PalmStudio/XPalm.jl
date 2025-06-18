module VPalm

# For the random number generator:
import Random

# For managing the MTG:
import MultiScaleTreeGraph: Node, MutableNodeMTG, traverse!, symbol, reparent!, addchild!, descendants, delete_nodes!, new_child_link

# IO:
import YAML, OrderedCollections

# For the 3D:
import PlantGeom
import Meshes
import TransformsBase: →
import Rotations: RotX, RotY, RotZ, RotYZ, RotXYZ, RotZY, RotYZX, RotZYX
import Rotations
import PlyIO
import Unitful: @u_str, ustrip, unit, NoUnits, uconvert, Quantity

# For the biomechanical model
import Interpolations: linear_interpolation

include("vpalm/units.jl")
include("vpalm/utils.jl")
include("vpalm/IO/parameters_IO.jl")

# Entry point:
include("vpalm/architecture/mtg_skeleton.jl")

# Biomechanical models
include("vpalm/biomechanics/complete/xyz_dist_angles.jl")
include("vpalm/biomechanics/complete/inertia_flex_rota.jl")
include("vpalm/biomechanics/complete/interpolate_points.jl")
include("vpalm/biomechanics/complete/bend.jl")
include("vpalm/biomechanics/complete/unbend.jl")
include("vpalm/biomechanics/simplified/young_modulus.jl")

# Allometries:
include("vpalm/allometries/stem.jl")
include("vpalm/allometries/internode.jl")
include("vpalm/allometries/leaf.jl")
include("vpalm/allometries/petiole.jl")

# Architecture:
include("vpalm/architecture/leaf_rank.jl")
include("vpalm/architecture/compute_properties_stem.jl")
include("vpalm/architecture/compute_properties_internode.jl")
include("vpalm/architecture/compute_properties_leaf.jl")
include("vpalm/architecture/compute_properties_petiole.jl")
include("vpalm/architecture/compute_properties_rachis.jl")

# Geometry:
include("vpalm/geometry/read_ply.jl")
include("vpalm/geometry/snag.jl")
include("vpalm/geometry/cylinder.jl")
include("vpalm/geometry/plane.jl")
include("vpalm/geometry/add_geometry.jl")
include("vpalm/geometry/sections.jl")
include("vpalm/geometry/leaflets.jl")

# Instance (create an organ with architecture + geometry)
include("vpalm/instance/petiole.jl")
include("vpalm/instance/rachis.jl")
include("vpalm/instance/leaflets.jl")

include("vpalm/build_mockup.jl")

export read_parameters, write_parameters
end
