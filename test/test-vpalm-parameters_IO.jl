@testset "read_parameters" begin
    @test vpalm_parameters["seed"] == 0
    @test vpalm_parameters["rachis_fresh_weight"] == uconvert.(u"kg", [
        2607.60521189879,
        2582.76405648725,
        2557.92290107571,
        2533.08174566417,
        2508.24059025263,
        2483.39943484109,
        2458.55827942956,
        2433.71712401802,
        2408.87596860648,
        2384.03481319494,
        2359.1936577834,
        2334.35250237186,
        2309.51134696033,
        2284.67019154879,
        2259.82903613725,
        2234.98788072571,
        2210.14672531417,
        2185.30556990263,
        2160.46441449109,
        2135.62325907956,
        2110.78210366802,
        2085.94094825648,
        2061.09979284494,
        2036.2586374334,
        2011.41748202186,
        1986.57632661033,
        1961.73517119879,
        1936.89401578725,
        1912.05286037571,
        1887.21170496417,
        1862.37054955263,
        1837.5293941411,
        1812.68823872956,
        1787.84708331802,
        1763.00592790648,
        1738.16477249494,
        1713.3236170834,
        1688.48246167187,
        1663.64130626033,
        1638.80015084879,
        1613.95899543725,
        1589.11784002571,
        1564.27668461417,
        1539.43552920264,
        1514.5943737911,
    ]u"g")
end

@testset "read_parameters with missing rachis_final_lengths" begin
    @test vpalm_parameters2["leaf_length_intercept"] == 3.6801281u"m"
    @test vpalm_parameters2["leaf_length_slope"] == 0.08769u"m/kg"
end

@testset "write_parameters" begin
    vpalm_parameters_w = mktemp() do f, io
        write_parameters(f, vpalm_parameters)
        vpalm_parameters_w = read_parameters(f)
        return vpalm_parameters_w
    end

    for (k, v) in vpalm_parameters
        isame = vpalm_parameters[k] == vpalm_parameters_w[k]
        if !isame
            println("params[$k] = $(vpalm_parameters[k]) != params2[$k] = $(vpalm_parameters_w[k])")
        end
        @test vpalm_parameters[k] == vpalm_parameters_w[k]
    end
end