

width_bend = 0.20u"m"
height_bend = 0.10u"m"
type_val = 1
npoints = 100

@testset "inertia_flex_rota works" begin
    @test VPalm.inertia_flex_rota(width_bend, height_bend, 0.0, type_val, npoints) == (ig_flex=5.556355779422049e-6u"m^4", ig_tor=2.2231354779522046e-5u"m^4", sr=0.010001u"m^2")
    @test VPalm.inertia_flex_rota(width_bend, height_bend, 45.0, type_val, npoints) == (ig_flex=1.3603727582400172e-5u"m^4", ig_tor=2.2231354779522046e-5u"m^4", sr=0.010001u"m^2")
    @test VPalm.inertia_flex_rota(width_bend, height_bend, 90.0, type_val, npoints) == (ig_flex=1.444533970624659e-5u"m^4", ig_tor=2.2231354779522042e-5u"m^4", sr=0.010001u"m^2")
end