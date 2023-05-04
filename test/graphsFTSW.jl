
using AlgebraOfGraphics
using DataFrames, CSV, Statistics
using DataFramesMeta

df = CSV.read("2-outputs/out_runFTSW.csv", DataFrame)
meteo = CSV.read("0-data/Exemple_meteo.csv", DataFrame)


lines(df.ftsw)

df = @chain df begin
    @transform :all_rain = :rain_effective + :runoff
    @transform :Rainfall = meteo.Rainfall
end


lines(df.all_rain - df.Rainfall)
lines(df.rain_remain)
