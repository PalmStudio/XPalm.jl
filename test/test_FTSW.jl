# Import dependencies
using PlantMeteo
using PlantGeom, CairoMakie
using DataFrames, CSV, AlgebraOfGraphics, Statistics

# include("../src/soil/FTSW.jl")

# m = ModelList(FTSW(),
#     status=())



# soil_init_default(m::FTSW, root_depth)


# run!(soil, meteo)

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

