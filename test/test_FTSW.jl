# Import dependencies
using PlantMeteo
using PlantGeom, CairoMakie
using DataFrames, CSV, AlgebraOfGraphics, Statistics

# include("../src/soil/FTSW.jl")

# m = ModelList(FTSW(),
#     status=())



# soil_init_default(m::FTSW, root_depth)


# run!(soil, meteo)


"""
    KS(fillRate, tresh)

Coefficient of stress. 

# Arguments

- `fillRate`: fill level of the compartment
- `tresh`: filling treshold of the  compartment below which there is a reduction in the flow
"""
KS(fillRate, tresh) = fillRate >= tresh ? 1 : 1 / (tresh) * fillRate



"""
    compute_compartment_size(m, root_depth)

Compute the size of the layers of the FTSW model.

# Arguments

- `m`: FTSW model
- `root_depth`: depth of the root system

# Returns

- `SizeC1`: size of the evapotranspirable water layer in the first soil layer (mm)
- `SizeVap`: size of the evaporative layer within the first layer (mm)
- `SizeC1minusVap`: size of the transpirable layer within the first layer (SizeC1-SizeVap)
- `SizeC2`: size of the transpirable water layer in the first soil layer (mm)
- `SizeC`: size of transpirable soil water (mm) (SizeC2 + SizeC1minusVap)
"""

function compute_compartment_size(param, root_depth)

    Taille_WP = param.H_WP[1] .* param.Z1[1]
    # Size of the evaporative component of the first layer:
    SizeVap = 0.5 * Taille_WP
    # NB: the 0.5 is because water can still evaporate below the wilting point
    # in the first layer, considered at 0.5 * H_WP. 
    #! replace 0.5 * m.H_WP by a parameter

    # Size of the evapotranspirable water layer in the first soil layer:
    if (root_depth > param.Z1[1])


        SizeC1 = param.H_FC[1] .* param.Z1[1] - (Taille_WP - SizeVap)
        # m.H_FC * m.Z1 -> size of the first layer at field capacity
        # (Taille_WP - SizeVap) -> size of the first layer that will never evapotranspirate
        # SizeC1 -> size of the first layer that can evapotranspirate
    else
        SizeC1 = param.H_FC[1] .* root_depth - SizeVap
    end
    SizeC1minusVap = SizeC1 - SizeVap


    if (root_depth > param.Z2[1] + param.Z1[1])
        SizeC2 = (param.H_FC[1] - param.H_WP[1]) .* param.Z2[1]
    else
        SizeC2 = max(0.0, (param.H_FC[1] - param.H_WP[1]) .* (root_depth - param.Z1[1]))
    end

    SizeC = SizeC2 + SizeC1minusVap

    return SizeC1, SizeVap, SizeC1minusVap, SizeC2, SizeC
end

function compute_fraction!(qty_H2O_C1, SizeC1, qty_H2O_C2, SizeC2, qty_H2O_C, SizeC)
    FractionC1 = qty_H2O_C1 / SizeC1
    if SizeC2 > 0
        FractionC2 = qty_H2O_C2 / SizeC2
    else
        FractionC2 = 0
    end
    ftsw = qty_H2O_C / SizeC
    return FractionC1, FractionC2, ftsw
end


function soil_init_default(m, root_depth)

    ## init compartments size
    SizeC1, SizeVap, SizeC1minusVap, SizeC2, SizeC = compute_compartment_size(m, root_depth)


    a_vap = min(SizeVap, (m.H_0[1] - m.H_WP_Z1[1]) * m.Z1[1])
    qty_H2O_Vap = max(0.0, a_vap)

    a_C1 = min(SizeC1, (m.H_0[1] - m.H_WP_Z1[1]) * m.Z1[1])
    qty_H2O_C1 = max(0.0, a_C1)

    a_C1moinsV = qty_H2O_C1 - qty_H2O_Vap
    qty_H2O_C1minusVap = max(0.0, a_C1moinsV)


    a_C2 = min(SizeC2, (m.H_0[1] - m.H_WP[1]) * m.Z2[1])
    qty_H2O_C2 = max(0.0, a_C2)

    a_C = qty_H2O_C1 + qty_H2O_C2 - qty_H2O_Vap
    qty_H2O_C = max(0.0, a_C)

    compute_fraction!(qty_H2O_C1, SizeC1, qty_H2O_C2, SizeC2, qty_H2O_C, SizeC)
end



### INPUTS

param = DataFrame(H_FC=0.23,
    H_WP_Z1=0.05,
    Z1=200.0,
    H_WP=0.1,
    Z2=2000.0,
    H_0=0.15,
    KC=1.0,
    TRESH_EVAP=0.5,
    TRESH_FTSW_TRANSPI=0.5)

# function PlantSimEngine.run!(m::FTSW, models, status, meteo, constants, extra=nothing)

function run(m, ext, rain)

    EvapMax = (1 - tree_ei) * ET0 * m.KC
    Transp_Max = ext.tree_ei * ext.ET0 * m.KC

    # estim effective rain
    if (0.916 * rain - 0.589) < 0
        rain_soil = 0
    else
        rain_soil = (0.916 * rain - 0.589)
    end

    if (0.0713 * rain - 0.735) < 0
        stemflow = 0
    else
        stemflow = (0.0713 * rain - 0.735)
    end

    rain_effective = rain_soil + stemflow

    # balance after rain
    mem_qty_H2O_C1 = qty_H2O_C1
    mem_qty_H2O_Vap = qty_H2O_Vap

    if (qty_H2O_Vap + rain_effective) >= SizeVap
        qty_H2O_Vap = SizeVap # evaporative compartment is full
        rain_remain = rain_effective - SizeVap
        if (qty_H2O_C1minusVap + (rain_remain + mem_qty_H2O_Vap)) >= SizeC1minusVap
            qty_H2O_C1minusVap = SizeC1minusVap # Transpirative compartment in the first layer is full
            qty_H2O_C1 = qty_H2O_C1minusVap + qty_H2O_Vap
            rain_remain = rain_effective - SizeC1
            if (qty_H2O_C2 + mem_qty_H2O_C1 + rain_remain) >= SizeC2
                qty_H2O_C2 = SizeC2 # Transpirative compartment in the second layer is full
                rain_remain = rain_effective - SizeC1 - SizeC2
            else
                qty_H2O_C2 += mem_qty_H2O_C1 + rain_remain - SizeC1
                rain_remain = 0
            end
        else
            qty_H2O_C1minusVap += rain_remain + mem_qty_H2O_Vap
            qty_H2O_C1 = qty_H2O_C1minusVap + qty_H2O_Vap
            rain_remain = 0
        end
    else
        qty_H2O_Vap += rain_effective
        qty_H2O_C1 = qty_H2O_Vap + qty_H2O_C1minusVap
        rain_remain = 0
    end
    qty_H2O_C = qty_H2O_C1minusVap + qty_H2O_C2

    compute_fraction!()

    # balance after evaporation
    Evap = EvapMax * KS(FractionC1, m.TRESH_EVAP)

    if qty_H2O_C1minusVap - Evap >= 0 # first evaporation on the evapotranspirative compartment
        qty_H2O_C1minusVap += -Evap
        EvapC1minusVap = Evap
        EvapVap = 0
    else
        EvapC1minusVap = qty_H2O_C1minusVap # then evaporation only on the evaporative compartment
        qty_H2O_C1minusVap = 0
        EvapVap = Evap - EvapC1minusVap
        qty_H2O_Vap += -EvapVap
    end
    qty_H2O_C1 = qty_H2O_C1minusVap + qty_H2O_Vap
    qty_H2O_C = qty_H2O_C1 + qty_H2O_C2 - qty_H2O_Vap


    compute_fraction!()

    # balance after transpiration
    Transpi = Transp_Max * KS(m.TRESH_FTSW_TRANSPI, ftsw)

    if qty_H2O_C2 > 0
        TranspiC2 = min(Transpi * (qty_H2O_C2 / (qty_H2O_C2 + qty_H2O_C1minusVap)), qty_H2O_C2)
    else
        TranspiC2 = 0
    end

    if qty_H2O_C1minusVap > 0
        TranspiC1minusVap = min(Transpi * (qty_H2O_C1minusVap / (qty_H2O_C2 + qty_H2O_C1minusVap)), qty_H2O_C1minusVap)
    else
        TranspiC1minusVap = 0
    end

    qty_H2O_C1minusVap += -TranspiC1minusVap
    qty_H2O_C2 += -TranspiC2
    qty_H2O_C = qty_H2O_C2 + qty_H2O_C1minusVap
    qty_H2O_C1 = qty_H2O_Vap + qty_H2O_C1minusVap

    compute_fraction!()
end



### run the model
meteo = CSV.read("0-data/Exemple_meteo.csv", DataFrame)

root_depth = 2000.0

### init
FractionC1, FractionC2, ftsw = soil_init_default(param, root_depth)


ext = DataFrame(tree_ei=0.8,
    ET0=0.05)


df=DataFrame()
df.Rain=meteo.Rainfall

for (i, row) in enumerate(eachrow(df))

