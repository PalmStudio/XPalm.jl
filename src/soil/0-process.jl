@process "soil_water" verbose = false

"""
    AbstractFTSWModel <: AbstractSoil_WaterModel

Defines a structure for soil water model that computes `ftsw` as an output.
"""
abstract type AbstractFTSWModel <: AbstractSoil_WaterModel end
PlantSimEngine.process_(::Type{AbstractFTSWModel}) = Symbol("soil_water")