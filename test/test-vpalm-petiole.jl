# Example parameters
parameters = Dict(
    "nb_sections" => 15,
    "rachis_length" => 2.0u"m",
    "leaf_max_angle" => 90u"°",
    "leaf_slope_angle" => 0.05, # Slope of the leaf angle for logistic function
    "leaf_inflection_angle" => 40, # Inflection point of the leaf angle for logistic function
    "cpoint_decli_intercept" => 10.4704506500867u"°", # Intercept of the linear regression of the c-point declination
    "cpoint_decli_slope" => 1.32703326824371, # Slope of the linear regression of the c-point declination
    "cpoint_angle_SDP" => 5.32416574941836u"°", # Standard deviation of the c-point angle
    "rachis_final_lengths" => [5.033523059699999, 5.019028172800001, 5.0045332858, 4.9900383989, 4.9755435119, 4.961048625, 4.946553738, 4.9320588511, 4.9175639642, 4.9030690772000005, 4.8885741903, 4.8740793033, 4.8595844164, 4.8450895295, 4.8305946425, 4.8160997556, 4.8016048686, 4.7871099817, 4.7726150947, 4.7581202078, 4.7436253209, 4.7291304339, 4.714635546999999, 4.70014066, 4.6856457731, 4.6711508860999995, 4.6566559992, 4.6421611123, 4.6276662253000005, 4.6131713384, 4.598676451399999, 4.584181564500001, 4.5696866775, 4.5551917906, 4.5406969037, 4.5262020167, 4.5117071298, 4.4972122428, 4.4827173559, 4.4682224689, 4.453727582, 4.4392326951, 4.4247378081, 4.4102429212, 4.3957480342]u"m",

    # Parameters for the petiole:
    "leaf_base_width" => 0.3u"m",
    "leaf_base_height" => 0.1u"m",
    "cpoint_width_intercept" => 0.00978257818097089u"m",
    "cpoint_width_slope" => 0.0119703143572554,
    "cpoint_height_width_ratio" => 0.567956652697377,
    "petiole_rachis_ratio_mean" => 0.248589010224887,
    "petiole_rachis_ratio_sd" => 0.0335377038720107,
    "petiole_nb_segments" => 15,
)

leaf_rank = 10
id = 12 # index in the rachis final length vector, which gives the lengths of the living leaves from old to new
rng = Random.MersenneTwister(1)

@testset "Petiole dimensions" begin
    zenithal_insertion_angle = VPalm.leaf_insertion_angle(
        leaf_rank,
        parameters["leaf_max_angle"],
        parameters["leaf_slope_angle"],
        parameters["leaf_inflection_angle"]
    )

    rachis_length = VPalm.rachis_expansion(leaf_rank, parameters["rachis_final_lengths"][id])
    zenithal_cpoint_angle = max(zenithal_insertion_angle, VPalm.c_point_angle(leaf_rank, parameters["cpoint_decli_intercept"], parameters["cpoint_decli_slope"], 0.0u"°"))

    mtg = Node(NodeMTG("/", "Plant", 1, 1))
    unique_id = Ref(2)
    petiole_node = VPalm.petiole(unique_id, 1, 5, rachis_length, zenithal_insertion_angle, zenithal_cpoint_angle, parameters; rng=rng)
    df_petiole_sections = DataFrame(petiole_node[1], [:width, :height, :length, :zenithal_angle_global, :azimuthal_angle_global])

    # All petiole sections have the same length:
    @test only(unique(df_petiole_sections.length)) ≈ petiole_node.length / parameters["petiole_nb_segments"]
    @test df_petiole_sections.width[1] == petiole_node.width_base
    @test df_petiole_sections.width[end] == petiole_node.width_cpoint
    @test df_petiole_sections.height[1] == petiole_node.height_base
    @test df_petiole_sections.height[end] == petiole_node.height_cpoint
    @test df_petiole_sections.zenithal_angle_global[1] ≈ 88.89542788681277u"°"
    @test petiole_node.zenithal_insertion_angle ≈ 89.77746391590287u"°"

    # The first petiole section always inserts with a 0.0 azimuthal angle:
    @test df_petiole_sections.azimuthal_angle_global[1] == 0.0u"°"
    # All others have the same azimuthal angle (global angle):
    @test all(df_petiole_sections.azimuthal_angle_global[2:end] .== petiole_node.azimuthal_angle)

    # The sum of all local angles of the sections of the petiole is equal to the angle at C point, which is the 
    # angle at the tip of the petiole
    local_angle = diff(df_petiole_sections.zenithal_angle_global)[2]
    @test local_angle * length(df_petiole_sections.zenithal_angle_global) ≈ petiole_node.zenithal_cpoint_angle - petiole_node.zenithal_insertion_angle

    # The length of all segments in the petiole is equal to the petiole length:
    @test sum(df_petiole_sections.length) ≈ petiole_node.length
end
