# VPalm Parameters

VPalm is a submodule of XPalm that provides a set of functions to reconstruct the architecture of palm trees based on a set of parameters and allometric relations.

Parameters are defined in a YAML file and a template is [provided](https://github.com/PalmStudio/XPalm.jl/blob/main/test/references/vpalm-parameter_file.yml):

```julia
using XPalm.VPalm
file = joinpath(dirname(dirname(pathof(XPalm))), "test", "references", "vpalm-parameter_file.yml")
parameters = read_parameters(file)
```

## Parameters definition

Here is a list of all necessary parameters to run XPalm.VPalm:

| Parameter | Value | Description |
|-----------|--------|-------------|
| `seed` | 0 | Seed for random number generation |
| `nb_leaves_emitted` | 145 | Number of leaves emitted since the seed |
| `nb_internodes_before_planting` | 20 | Number of internodes before planting (estimation) |
| `nb_leaves_in_sheath` | 8 | Number of leaves in the sheath (rank <1) |
| `phyllotactic_angle_mean` | 136.67 | Frond phyllotactic angle mean (°) |
| `phyllotactic_angle_sd` | 0.48 | Frond phyllotactic angle standard deviation (°) |
| `initial_stem_height` | 0.05 | Stem height at planting (m) |
| `stem_height_coefficient` | 0.018 | Coefficient used in the computation of stem height |
| `internode_length_at_maturity` | 0.03 | Growth in stem height per leaf (~internode length) at adult stage (m) |
| `stem_growth_start` | 120 | Number of leaves emitted when stem starts to grow in height |
| `stem_height_variation` | 0.50 | Variation in stem height (m, never > 30% of stem height) |
| `stem_bending_mean` | 0 | Average stem bending |
| `stem_bending_sd` | 0 | Standard deviation around mean stem bending |
| `stem_diameter_max` | 0.77 | Maximum stem diameter (m) |
| `stem_diameter_slope` | 0.007 | Slope of the logit function for stem diameter |
| `stem_diameter_inflection` | 1.69 | Inflection point of the logit function for stem diameter |
| `stem_diameter_residual` | 0.063 | Residual of stem diameter (m) |
| `stem_diameter_snag` | 0.3 | Diameter of stem considered as snag (m) |
| `stem_base_shrinkage` | 0.1 | Shrinkage at stem base (smaller = sharper) |
| `stem_top_shrinkage` | 0.3 | Shrinkage at stem top (smaller = sharper) |
| `internode_rank_no_expansion` | 9 | Rank of internode where expansion stops |
| `internode_final_length` | 0.01 | Length of internode around apical meristem (m) |
| `leaf_max_angle` | 90 | Maximum angle of the leaf (°) |
| `leaf_slope_angle` | 0.05 | Slope of leaf angle for logistic function |
| `leaf_inflection_angle` | 40 | Inflection point of leaf angle for logistic function |
| `cpoint_decli_intercept` | 10.47 | Intercept of linear regression of c-point declination |
| `cpoint_decli_slope` | 1.33 | Slope of linear regression of c-point declination |
| `cpoint_angle_SDP` | 5.32 | Standard deviation of c-point angle |
| `rachis_twist_initial_angle` | 4.0 | Initial twist angle of rachis |
| `rachis_twist_initial_angle_sdp` | 0.0 | Standard deviation of initial twist angle of rachis |
| `petiole_rachis_ratio_mean` | 0.25 | Mean ratio of petiole length to rachis length |
| `petiole_rachis_ratio_sd` | 0.033 | Standard deviation of petiole to rachis length ratio |
| `petiole_nb_segments` | 15 | Number of segments in the petiole |
| `rachis_nb_segments` | 100 | Number of segments in the rachis |
| `leafLengthIntercept` | 351.20 | Intercept for leaf length calculation |
| `leafLengthSlope` | 0.058 | Slope for leaf length calculation |
| `rachisLength_SDP` | 15.25 | Standard deviation of rachis length |
| `rachis_fresh_weight` | [array] | Fresh weight of rachis (g) for each leaf |
| `leaf_length_intercept` | 0.0 | Intercept of the linear relationship between rachis length and biomass (m) (optional, can use `rachis_final_lengths` instead)|
| `leaf_length_slope` | 1.31 | Slope of the linear relationship between rachis length and biomass (m/kg) (optional, can use `rachis_final_lengths` instead) |
| `rachis_final_lengths` | [array] | Final rachis lengths (m) from oldest to rank 1 leaf (optional, can use `leaf_length_intercept` + `leaf_length_slope` instead) |
| `leaflet_lamina_angle` | 140 | V-shape angle of leaflet (°) |
| `leaflets_nb_max` | 171.72 | Maximum number of leaflets on a leaf |
| `leaflets_nb_min` | 20 | Minimum number of leaflets on a leaf |
| `leaflets_nb_slope` | 0.25 | Slope of logistic relationship between rachis length and nb leaflets |
| `leaflets_nb_inflexion` | 2.33 | Inflection point of logistic relationship (rachis length vs nb leaflets) |
| `nbLeaflets_SDP` | 6 | Standard deviation around computed value for given rachis length |
| `leaflet_position_shape_coefficient` | 2.48 | Shape coefficient for placing leaflets along rachis |
| `leaflets_between_to_within_group_ratio` | 2.0 | Ratio of inter-group to intra-group leaflets spacing |
| `relative_position_bpoint` | 0.66 | Relative position of b-point |
| `relative_position_bpoint_sd` | 0.034 | Standard deviation of relative position of b-point |
| `leaflet_length_at_b_intercept` | 0.61 | Intercept of leaflet length at b-point (m) |
| `leaflet_length_at_b_slope` | 0.054 | Slope of leaflet length at b-point |
| `leaflet_width_at_b_intercept` | 0.063 | Intercept of leaflet width at b-point |
| `leaflet_width_at_b_slope` | -0.004 | Slope of leaflet width at b-point |
| `relative_length_first_leaflet` | 0.18 | Relative length of first leaflet |
| `relative_length_last_leaflet` | 0.52 | Relative length of last leaflet |
| `relative_position_leaflet_max_length` | 0.52 | Relative position of leaflet with maximum length |
| `relative_width_first_leaflet` | 0.22 | Relative width of first leaflet |
| `relative_width_last_leaflet` | 0.53 | Relative width of last leaflet |
| `relative_position_leaflet_max_width` | 0.61 | Relative position of leaflet with maximum width |
| `leaflet_xm_intercept` | 0.18 | Base value for xm (position of maximum width) for leaflets |
| `leaflet_xm_slope` | 0.08 | How much xm changes per unit of relative position along rachis |
| `leaflet_ym_intercept` | 0.51 | Base value for relative width at maximum width position |
| `leaflet_ym_slope` | -0.025 | How much relative width changes per unit of position along rachis |
| `leaflet_axial_angle_c` | 78.22 | Leaflet axial angle parameter c |
| `leaflet_axial_angle_a` | 10.43 | Leaflet axial angle parameter a |
| `leaflet_axial_angle_slope` | -4.69 | Leaflet axial angle slope |
| `leaflet_axial_angle_sdp` | 8.06 | Standard deviation of leaflet axial angle |
| `leaflet_stiffness` | 1500 | Leaflet stiffness |
| `leaflet_stiffness_sd` | 7000 | Standard deviation of leaflet stiffness |
| `leaflet_frequency_high` | [array] | Frequency of high position leaflets along 10 rachis sub-sections |
| `leaflet_frequency_low` | [array] | Frequency of low position leaflets along 10 rachis sub-sections |
| `nbInflorescences` | 0 | Number of inflorescences |
| `leaf_base_width` | 0.3 | Width of leaf base (m) |
| `cpoint_width_intercept` | 0.01 | Rachis width at c-point intercept for linear interpolation (m) |
| `cpoint_width_slope` | 0.012 | Rachis width at c-point slope for linear interpolation |
| `rachis_width_tip` | 0.03 | Width at tip of rachis (m) |
| `leaf_base_height` | 0.1 | Height of leaf base (m) |
| `cpoint_height_width_ratio` | 0.57 | Height to width ratio at c-point |
| `height_rachis_tappering` | -0.93 | Tapering factor for rachis height |
| `leaflet_radial_high_a0_sup` | 26.30 | Upper bound of leaflet angle at position 0 for high position leaflets |
| `leaflet_radial_high_amax_sup` | 60.49 | Upper bound of maximum angle for high position leaflets |
| `leaflet_radial_high_a0_inf` | 16.66 | Lower bound of angle at position 0 for high position leaflets |
| `leaflet_radial_high_amax_inf` | 9.08 | Lower bound of maximum angle for high position leaflets |
| `leaflet_radial_low_a0_sup` | -7.91 | Upper bound of angle at position 0 for low position leaflets |
| `leaflet_radial_low_amax_sup` | -4.83 | Upper bound of maximum angle for low position leaflets |
| `leaflet_radial_low_a0_inf` | -12.29 | Lower bound of angle at position 0 for low position leaflets |
| `leaflet_radial_low_amax_inf` | -34.33 | Lower bound of maximum angle for low position leaflets |
| `elastic_modulus` | 2221.67 | Elastic modulus for biomechanical calculations |
| `shear_modulus` | 68.20 | Shear modulus for biomechanical calculations |

### Biomechanical Model Parameters

| Parameter | Value | Description |
|-----------|--------|-------------|
| `nb_sections` | 100 | Number of sections for discretizing constant form sections |
| `angle_max` | 21.0 | Maximum flexion and torsion angles between sections (°) |
| `iterations` | 15 | Number of iterations for recursive computation |