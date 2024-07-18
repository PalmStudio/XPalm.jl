using XPalm
using Test
using Dates
using MultiScaleTreeGraph, PlantMeteo, PlantSimEngine
using CSV, DataFrames, Statistics

# Import the meteo data once:

meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/Exemple_meteo.csv"), DataFrame)

rename!(
    meteo,
    :TMin => :Tmin,
    :TMax => :Tmax,
    :HRMin => :Rh_min,
    :HRMax => :Rh_max,
    :Rainfall => :Precipitations,
    :WindSpeed => :Wind,
)

# prevent missing values
replace!(meteo.Wind, missing => mean(skipmissing(meteo.Wind)))
replace!(meteo.Rg, missing => mean(skipmissing(meteo.Rg)))
transform!(
    meteo,
    :Rg => (x -> x .* 0.48) => :Ri_PAR_f,
)

dirtest = joinpath(dirname(dirname(pathof(XPalm))), "test/")

@testset "Age_modulation" begin
    include(joinpath(dirtest, "test-age_modulation_linear.jl"))
    include(joinpath(dirtest, "test-age_modulation_logistic.jl"))
end

@testset "Light" begin
    include(joinpath(dirtest, "test-beer.jl"))
end

@testset "Meteo" begin
    include(joinpath(dirtest, "test-et0.jl"))
    include(joinpath(dirtest, "test-thermal_time.jl"))
    include(joinpath(dirtest, "test-thermal_time_ftsw.jl"))
end

@testset "Carbon_allocation" begin
    include(joinpath(dirtest, "test-carbon_allocation.jl"))
end

@testset "Carbon_assimilation" begin
    include(joinpath(dirtest, "test-rue.jl"))
end

@testset "Carbon_offer" begin
    include(joinpath(dirtest, "test-carbon_offer_photosynthesis.jl"))
    include(joinpath(dirtest, "test-carbon_offer_rm.jl"))
end

@testset "Dimensions" begin
    include(joinpath(dirtest, "test-actual_dimension.jl"))
    include(joinpath(dirtest, "test-final_potential_dimensions.jl"))
    include(joinpath(dirtest, "test-potential_dimensions.jl"))
    include(joinpath(dirtest, "test-final_potential_area.jl"))
    include(joinpath(dirtest, "test-potential_area.jl"))
    include(joinpath(dirtest, "test-leaf_area.jl"))
    include(joinpath(dirtest, "test-LAI_growth.jl"))
    include(joinpath(dirtest, "test-lai.jl"))
    include(joinpath(dirtest, "test-number_spikelets.jl"))
    include(joinpath(dirtest, "test-number_fruits.jl"))
end

@testset "Biomass" begin
    include(joinpath(dirtest, "test-biomass_internode.jl"))
    include(joinpath(dirtest, "test-biomass_leaf.jl"))
end

@testset "Carbon_demand" begin

end


@testset "Soil" begin
    include(joinpath(dirtest, "test-FTSW_BP.jl"))
    include(joinpath(dirtest, "test-FTSW.jl"))
end

@testset "Roots" begin
    include(joinpath(dirtest, "test-roots.jl"))
end



@testset "Palm" begin
    include(joinpath(dirtest, "test-palm.jl"))
end

@testset "Running a simulation" begin
    include("test-run.jl")
end

@testset "PlantSimEngine" begin
    include("test-PlantSimEngine.jl")
end

