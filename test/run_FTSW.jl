# Import dependencies
using PlantMeteo, PlantSimEngine, Revise
# using PlantGeom, CairoMakie, AlgebraOfGraphics
using DataFrames, CSV, Statistics
using CairoMakie

includet("../src/soil/FTSW.jl")
includet("../src/ThermalTime.jl")
meteo = CSV.read("0-data/Exemple_meteo.csv", DataFrame)

soil = FTSW()
init = soil_init_default(soil, 1000.0)
init.ET0 = 1.0
init.tree_ei = 0.8

# meteo = first(meteo, 20)
m = ModelList(
    ThermalTime(),
    FTSW(),
    status=TimeStepTable{Status}([init for i in eachrow(meteo)])
    # status=TimeStepTable{Status}([init for i in eachrow(meteo)])
)

run!(m, meteo)
# lines(m[:ftsw])

# export outputs
df = DataFrame(m)
CSV.write("2-outputs/out_runFTSW.csv", df)






# ##### debug


# # Which time step is the first one where qty_H2O_C < 0.0?
# bugligne = findfirst(x -> x < 0.0, m[:qty_H2O_C])

# # Get the status of the model at that time step:
# status(m)[bugligne]


# # Print all the values of the status at that time step:
# prev = PlantMeteo.row_struct(status(m)[bugligne-1])
# st = PlantMeteo.row_struct(status(m)[bugligne])

# rain = meteo.Rainfall[bugligne-1]

# # Initialize the water content to the values from the previous time step
# st.qty_H2O_C1minusVap = prev.qty_H2O_C1minusVap
# st.qty_H2O_C2 = prev.qty_H2O_C2
# st.qty_H2O_C = prev.qty_H2O_C
# st.qty_H2O_C1 = prev.qty_H2O_C1



# ### check rain balance rain=rain_effective+rain_run_off+rain_remain

# EvapMax = (1 - st.tree_ei) * st.ET0
# Transp_Max = st.tree_ei * st.ET0

# # estim effective rain (runoff)
# if (0.916 * rain - 0.589) < 0
#     rain_soil = 0
# else
#     rain_soil = (0.916 * rain - 0.589)
# end

# if (0.0713 * rain - 0.735) < 0
#     stemflow = 0
# else
#     stemflow = (0.0713 * rain - 0.735)
# end

# st.rain_effective = rain_soil + stemflow

# st.runoff = rain - st.rain_effective

# # balance after rain
# # mem_qty_H2O_C1 = copy(st.qty_H2O_C1)
# # mem_qty_H2O_Vap = copy(st.qty_H2O_Vap)

# if (st.qty_H2O_Vap + st.rain_effective) >= st.SizeVap
#     st.rain_remain = st.rain_effective + st.qty_H2O_Vap - st.SizeVap
#     st.qty_H2O_Vap = st.SizeVap # evaporative compartment is full
#     if (st.qty_H2O_C1minusVap + st.rain_remain) >= st.SizeC1minusVap
#         st.rain_remain = st.rain_remain + st.qty_H2O_C1minusVap - st.SizeC1minusVap
#         st.qty_H2O_C1minusVap = st.SizeC1minusVap # Transpirative compartment in the first layer is full
#         st.qty_H2O_C1 = st.qty_H2O_C1minusVap + st.qty_H2O_Vap

#         if (st.qty_H2O_C2 + st.rain_remain) >= st.SizeC2
#             st.rain_remain = st.rain_remain + st.qty_H2O_C2 - st.SizeC2
#             st.qty_H2O_C2 = st.SizeC2 # Transpirative compartment in the second layer is full

#         else
#             st.qty_H2O_C2 += st.rain_remain
#             st.rain_remain = 0.0
#         end
#     else
#         st.qty_H2O_C1minusVap += st.rain_remain
#         st.qty_H2O_C1 = st.qty_H2O_C1minusVap + st.qty_H2O_Vap
#         st.rain_remain = 0.0
#     end
# else
#     st.qty_H2O_Vap += st.rain_effective
#     st.qty_H2O_C1 = st.qty_H2O_Vap + st.qty_H2O_C1minusVap
#     st.rain_remain = 0.0
# end
# st.qty_H2O_C = st.qty_H2O_C1minusVap + st.qty_H2O_C2

# compute_fraction!(st)

# # balance after evaporation
# Evap = EvapMax * KS(st.FractionC1, m.TRESH_EVAP)

# if st.qty_H2O_C1minusVap - Evap >= 0.0 # first evaporation on the evapotranspirative compartment
#     st.qty_H2O_C1minusVap += -Evap
#     EvapC1minusVap = Evap
#     EvapVap = 0.0
# else
#     EvapC1minusVap = st.qty_H2O_C1minusVap # then evaporation only on the evaporative compartment
#     st.qty_H2O_C1minusVap = 0.0
#     EvapVap = Evap - EvapC1minusVap
#     if st.qty_H2O_Vap - EvapVap >= 0.0 #  evaporation on the evaporative compartment
#         st.qty_H2O_Vap += -EvapVap
#         EvapVap = 0.0
#     else
#         EvapVap = EvapVap - st.qty_H2O_Vap
#         st.qty_H2O_Vap = 0.0
#     end

# end
# st.qty_H2O_C1 = st.qty_H2O_C1minusVap + st.qty_H2O_Vap
# st.qty_H2O_C = st.qty_H2O_C1 + st.qty_H2O_C2 - st.qty_H2O_Vap

# compute_fraction!(st)

# # balance after transpiration
# Transpi = Transp_Max * KS(m.TRESH_FTSW_TRANSPI, st.ftsw)

# if st.qty_H2O_C2 > 0.0
#     TranspiC2 = min(Transpi * (st.qty_H2O_C2 / (st.qty_H2O_C2 + st.qty_H2O_C1minusVap)), st.qty_H2O_C2)
# else
#     TranspiC2 = 0
# end

# if st.qty_H2O_C1minusVap > 0
#     TranspiC1minusVap = min(Transpi * (st.qty_H2O_C1minusVap / (st.qty_H2O_C2 + st.qty_H2O_C1minusVap)), st.qty_H2O_C1minusVap)
# else
#     TranspiC1minusVap = 0
# end

# st.qty_H2O_C1minusVap += -TranspiC1minusVap
# st.qty_H2O_C2 += -TranspiC2
# st.qty_H2O_C = st.qty_H2O_C2 + st.qty_H2O_C1minusVap
# st.qty_H2O_C1 = st.qty_H2O_Vap + st.qty_H2O_C1minusVap
