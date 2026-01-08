shader_type spatial;
//render_mode unshaded; // for debugging
render_mode unshaded;

#include "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/SVO.gdshaderinc"
#include "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/ByteFunctions.gdshaderinc"
#include "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/DDA.gdshaderinc"

#define MAX_DISTANCE 1000.0 // maximum distance to ray march (float)
#define ERROR_COLOR vec4(1.0,0.2,0.6,1)


uniform int voxel_count_x : hint_range(1, 2500) = 3;
uniform int voxel_count_y : hint_range(1, 2500) = 3;
uniform int voxel_count_z : hint_range(1, 2500) = 3;
uniform float voxel_opacity : hint_range(0.0, 1.0) = 0.2;
uniform vec3 voxel_color : source_color = vec3(0.0, 0.2, 0.0);
uniform int shared_SVO_depth: hint_range(1, SVO_MAX_DEPTH); // All SVOs use the same depth factor. This is the depth of the SVO tree (root included)
uniform sampler2D activation_SVO : hint_default_black;
uniform sampler2D highlight_SVO: hint_default_black;
uniform sampler2D selection_SVO: hint_default_black;

// Edge visibility tuning (Option 5: distance-based scaling)
// Goal: thin/small areas remain readable from far away without reintroducing interior artifacts.
uniform float edge_camera_near : hint_range(0.0, 200.0) = 12.0; // Distance where edge boost begins
uniform float edge_camera_far : hint_range(0.0, 500.0) = 80.0;  // Distance where edge boost maxes out
uniform float edge_thickness_near : hint_range(0.001, 0.05) = 0.008; // Baseline edge thickness
uniform float edge_thickness_far : hint_range(0.001, 0.08) = 0.02;   // Thicker edges when zoomed out
uniform float edge_opacity_far_boost : hint_range(0.0, 0.6) = 0.25;  // Extra opacity added when zoomed out

varying vec3 local_vert_space_m05_05; // Goes from -0.5 -> 0.5  across the actual mesh surface of the cube
//varying vec3 local_vert_space_0_1; // Goes from 0.0 -> 1.0 across the actual mesh surface of the cube
//varying vec3 shared_SVO_vert_space; //  0.0 - 1.0, but for the size of the Sparse Voxel Octet tree cube, this means any non-2^n mesh will not reach 1.0
varying vec3 individual_voxel_size; // Normalized (0 - 1.0) size of each voxel (mesh wise)
varying vec3 world_pos_ws; // World-space position (interpolated) for distance-based edge scaling

// Calculates the distance the ray traveled within the entire object // TESTED, NO ARTIFACTS
float get_distance_traveled_by_ray_in_entire_object(vec3 starting_normalized_position, vec3 normalized_ray_direction)
{
	vec3 ray_axis_direction  = sign(normalized_ray_direction); // get ray direction as per axis (-1 or 1 in each direction of the XYZ axis)
	vec3 boundry_condition = (ray_axis_direction) / 2.0; // Gets the bounds we are checking aginst
	vec3 slope = (boundry_condition - starting_normalized_position) / normalized_ray_direction; // Get longest distance to travel in each direction. smallest value location is the boundry limiting axis

	// Pick the shortest of the 3 elements
	if (slope.x < slope.y && slope.x < slope.z)
	{
		return slope.x;
	}
	else if (slope.y < slope.z)
	{
		return slope.y; // y
    }
	else
	{
        return slope.z; // z
    }
}

// Gets number of intersections of wall intersections given a start point, direction, and the voxel sizes // BROKEN, ARTIFACTING WITH MISSING WALLS DEPENDING ON EPSILON
ivec3 get_number_wall_intersections(vec3 starting_normalized_position, vec3 normalized_voxel_size, vec3 normalized_ray_direction)
{
	const float EPSILON = 1e-6; // To help deal with floating point error
	vec3 ray_axis_direction  = sign(normalized_ray_direction); // get ray direction as per axis (-1 or 1 in each direction of the XYZ axis)
	float distance_traveled = get_distance_traveled_by_ray_in_entire_object(starting_normalized_position, normalized_ray_direction) + EPSILON;
	vec3 ending_normalized_position = distance_traveled * normalized_ray_direction + starting_normalized_position;

	//ivec3 end_count = ivec3(floor((ending_normalized_position) / normalized_voxel_size));
	//ivec3 start_count = ivec3(floor((starting_normalized_position) / normalized_voxel_size));

	// TEMP
	ivec3 end_count = ivec3(floor((ending_normalized_position) / normalized_voxel_size));
	ivec3 start_count = ivec3(floor((starting_normalized_position) / normalized_voxel_size));
	//ivec3 end_count = ivec3(floor((ending_normalized_position) / normalized_voxel_size));
	//ivec3 start_count = ivec3(floor((starting_normalized_position) / normalized_voxel_size));

	return abs(end_count - start_count);
}



void vertex() {
	vec3 mesh_scale = vec3(length(MODEL_MATRIX[0].xyz), // Gets the X Y Z scale of the mesh itself
                length(MODEL_MATRIX[1].xyz),
                length(MODEL_MATRIX[2].xyz));

	// Range of the following is accross the actual surface of the cube
	local_vert_space_m05_05 = VERTEX;
	//local_vert_space_0_1 = VERTEX + 0.5;
	//shared_SVO_vert_space = local_vert_0_1_space_to_SVO_space(local_vert_space_0_1, mesh_scale, shared_SVO_depth);

	// Constants
	individual_voxel_size = vec3(1.0 / float(voxel_count_x), 1.0 / float(voxel_count_y), 1.0 / float(voxel_count_z));
	world_pos_ws = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}




// Called for every pixel the material is visible on.
void fragment()
{
	// ACRONYMS
	// _m -> mesh space, _mn -> mesh space normalized (0-1)
	// _svo -> SVO space, _svon -> SVO space normalized (0-1)

	vec4 final_color = vec4(voxel_color, 0.0); // this will be the output (pixel color)

	/// Various constants for this ray
	// General Propertes
	vec3 voxel_counts_per_dim = vec3(float(voxel_count_x),float(voxel_count_y) ,float(voxel_count_z));

	// Get Ray variations
    vec3 ray_origin_m = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1)).xyz;
    vec3 ray_direction_mn = normalize(local_vert_space_m05_05 - ray_origin_m);
	vec3 ray_direction_svon = normalize(local_vert_0_1_space_to_SVO_space(ray_direction_mn, voxel_counts_per_dim, shared_SVO_depth));

	// Get Space variations
	vec3 mesh_surface_position_mn = local_vert_space_m05_05 + vec3(0.5);
	vec3 mesh_surface_position_svon = local_vert_0_1_space_to_SVO_space(mesh_surface_position_mn, voxel_counts_per_dim, shared_SVO_depth);

	/// Calculate SVO hits
	// Neuron Activation SVO
	SVOInternalNode neuron_activation_root_SVO = read_SVO_node(activation_SVO, 0u, 0u);
	vec3 neuron_activation_hit_normal_svon;
	vec3 neuron_activation_hit_offset_svon;
	vec3 neuron_activation_hit_coordinate_svon;
	bool neuron_activation_has_hit = get_01_model_distance_to_voxel_DDA(activation_SVO, neuron_activation_root_SVO, mesh_surface_position_svon, ray_direction_svon, neuron_activation_hit_offset_svon, neuron_activation_hit_normal_svon, neuron_activation_hit_coordinate_svon);

	// Neuron Highlighting SVO
	SVOInternalNode neuron_highlight_root_SVO = read_SVO_node(highlight_SVO, 0u, 0u);
	vec3 neuron_highlight_hit_normal_svon;
	vec3 neuron_highlight_hit_offset_svon;
	vec3 neuron_highlight_hit_coordinate_svon;
	bool neuron_highlight_has_hit = get_01_model_distance_to_voxel_DDA(highlight_SVO, neuron_highlight_root_SVO, mesh_surface_position_svon, ray_direction_svon, neuron_highlight_hit_offset_svon, neuron_highlight_hit_normal_svon, neuron_highlight_hit_coordinate_svon);

	// Neuron Selection SVO
	SVOInternalNode neuron_selection_root_SVO = read_SVO_node(selection_SVO, 0u, 0u);
	vec3 neuron_selection_hit_normal_svon;
	vec3 neuron_selection_hit_offset_svon;
	vec3 neuron_selection_hit_coordinate_svon;
	bool neuron_selection_has_hit = get_01_model_distance_to_voxel_DDA(selection_SVO, neuron_selection_root_SVO, mesh_surface_position_svon, ray_direction_svon, neuron_selection_hit_offset_svon, neuron_selection_hit_normal_svon, neuron_selection_hit_coordinate_svon);



	// IMPORTANT: Do NOT use get_number_wall_intersections() for transparency.
	// That path is marked as broken (artifacting) and it produces interior "cross planes"
	// in thin areas (e.g., 1x1x10) that obscure neuron firing.
	//
	// Instead: render ONLY a thin outer shell (faces) and solid geometric edges.
	vec3 abs_position = abs(local_vert_space_m05_05); // Distance from center
	
	// Calculate dimensions and proportions
	float dim_x = float(voxel_count_x);
	float dim_y = float(voxel_count_y);
	float dim_z = float(voxel_count_z);
	float max_dimension = max(max(dim_x, dim_y), dim_z);
	float min_dimension = min(min(dim_x, dim_y), dim_z);
	float volume = dim_x * dim_y * dim_z;
	
	// Calculate aspect ratio (how elongated/flat the area is)
	// High aspect ratio = thin/flat area (e.g., 64x64x1), low = cubic (e.g., 5x5x5)
	float aspect_ratio = max_dimension / max(min_dimension, 1.0);
	
	// SIZE-BASED OPACITY SCALING: Inverse relationship between size and opacity
	// Small areas need high opacity to be visible, large areas need low opacity to not obscure neurons
	float size_opacity_factor = 1.0;
	
	// Determine area "size category" based on volume and max dimension
	// Use logarithmic scaling for smooth transitions
	float volume_log = log(max(volume, 1.0)) / log(10.0); // log10 of volume
	
	if (volume_log < 1.0) {
		// Very small areas (1-10 voxels): High opacity (0.8-1.0)
		// Example: 2x2x2 = 8 voxels, 3x3x1 = 9 voxels
		size_opacity_factor = 0.8 + 0.2 * (1.0 - volume_log); // 0.8 to 1.0
	} else if (volume_log < 2.0) {
		// Small areas (10-100 voxels): Medium-high opacity (0.5-0.8)
		// Example: 4x4x4 = 64 voxels, 5x5x4 = 100 voxels
		size_opacity_factor = 0.5 + 0.3 * (2.0 - volume_log); // 0.5 to 0.8
	} else if (volume_log < 3.0) {
		// Medium areas (100-1000 voxels): Medium opacity (0.2-0.5)
		// Example: 10x10x10 = 1000 voxels
		size_opacity_factor = 0.2 + 0.3 * (3.0 - volume_log); // 0.2 to 0.5
	} else if (volume_log < 4.0) {
		// Large areas (1000-10000 voxels): Low-medium opacity (0.08-0.2)
		// Example: 20x20x20 = 8000 voxels
		size_opacity_factor = 0.08 + 0.12 * (4.0 - volume_log); // 0.08 to 0.2
	} else {
		// Very large areas (10000+ voxels): Very low opacity (0.02-0.08)
		// Example: 50x50x10 = 25000 voxels
		size_opacity_factor = 0.02 + 0.06 * min(1.0, (5.0 - volume_log)); // 0.02 to 0.08
	}
	
	// Adjust for aspect ratio: Thin/flat areas need slightly higher opacity for borders
	// This ensures 64x64x1 areas have visible borders even though volume is small
	float aspect_adjustment = 1.0;
	if (aspect_ratio > 10.0) {
		// Very thin areas: Boost opacity slightly (up to 1.2x)
		aspect_adjustment = 1.0 + 0.2 * min(1.0, (aspect_ratio - 10.0) / 50.0);
	}
	
	// Thin outer shell only (no interior walls)
	vec3 distance_to_faces = vec3(0.5) - abs_position; // Distance to each face (0 at face)
	float min_distance_to_face = min(min(distance_to_faces.x, distance_to_faces.y), distance_to_faces.z);
	float shell_thickness = 0.02; // Thin shell in mesh space (0..0.5)
	float shell_mask = 1.0 - smoothstep(0.0, shell_thickness, min_distance_to_face); // 1 at face, 0 inside
	
	// Faces should stay faint so they don't obscure neuron firing (especially in narrow areas).
	// Edges will provide the strong visual boundary instead.
	float face_alpha_scale = 0.25; // default for tiny areas (multiplies voxel_opacity)
	if (volume_log >= 2.0) face_alpha_scale = 0.18;
	if (volume_log >= 3.0) face_alpha_scale = 0.12;
	if (volume_log >= 4.0) face_alpha_scale = 0.08;
	
	// Narrow/elongated areas: make faces extremely faint (avoid the "blue tube" masking firing)
	if (aspect_ratio > 3.0) face_alpha_scale *= 0.25;
	if (aspect_ratio > 8.0) face_alpha_scale *= 0.1;
	
	float wall_transparency = voxel_opacity * shell_mask * face_alpha_scale;

	// EDGE DETECTION: Detect geometric edges (where 2-3 faces meet) only
	// These are the actual edges/corners where faces meet, not the entire surfaces
	// Distance-based scaling: thicker + more opaque edges when camera is far away.
	// Note: we use interpolated world_pos_ws for stable behavior.
	float cam_dist = distance(world_pos_ws, CAMERA_POSITION_WORLD);
	float edge_dist_t = smoothstep(edge_camera_near, edge_camera_far, cam_dist);

	// Size-based cap: large cortical areas shouldn't get excessively thick edges when zoomed out.
	// volume_log: 2 -> ~100 voxels, 4 -> ~10,000 voxels
	float edge_large_area_t = smoothstep(2.0, 4.0, volume_log);
	float edge_thickness_far_capped = mix(edge_thickness_far, edge_thickness_far * 0.5, edge_large_area_t);

	float edge_thickness = mix(edge_thickness_near, edge_thickness_far_capped, edge_dist_t);
	bool is_on_edge = false;
	
	// Count how many faces we're close to
	int faces_close_to = 0;
	if (distance_to_faces.x <= edge_thickness) faces_close_to++;
	if (distance_to_faces.y <= edge_thickness) faces_close_to++;
	if (distance_to_faces.z <= edge_thickness) faces_close_to++;
	
	// We're on an edge if we're close to exactly 2 faces (edge) or 3 faces (corner)
	if (faces_close_to >= 2) {
		is_on_edge = true;
	}

	/// Calculate final pixel color - PRESERVE SHELL TRANSPARENCY
	final_color.a = wall_transparency;
	
	// RENDER GEOMETRIC EDGES ONLY: Solid lines where faces meet
	if (is_on_edge) {
		// Edge color for clear visibility
		final_color.rgb = vec3(0.45, 0.5, 0.6); // Gray-blue for good contrast
		
		// Calculate guaranteed minimum edge opacity - ensures visibility even for large transparent areas
		float edge_opacity_min = 0.5; // Minimum guaranteed opacity for large areas (solid line)
		float edge_opacity_max = 0.95; // Maximum opacity for small areas
		
		float edge_opacity;
		if (volume_log < 1.0) {
			// Very small areas: Near-solid edges
			edge_opacity = edge_opacity_max;
		} else if (volume_log < 2.0) {
			// Small areas: High edge opacity
			edge_opacity = 0.8 + 0.15 * (2.0 - volume_log); // 0.8 to 0.95
		} else if (volume_log < 3.0) {
			// Medium areas: Medium-high edge opacity
			edge_opacity = 0.6 + 0.2 * (3.0 - volume_log); // 0.6 to 0.8
		} else {
			// Large areas: Guaranteed minimum visibility (solid line)
			// Scale from edge_opacity_min up to 0.6 for medium-large
			edge_opacity = edge_opacity_min + 0.1 * min(1.0, (4.0 - volume_log)); // 0.5 to 0.6
		}

		// Zoomed-out boost (Option 5): edges get more visible at distance.
		edge_opacity = min(edge_opacity + (edge_opacity_far_boost * edge_dist_t), 1.0);
		
		// Edges always override interior transparency for visibility
		final_color.a = max(wall_transparency, edge_opacity);
	}
	
	if(neuron_highlight_has_hit)
	{
		final_color.b = 1.0;
		// Neuron highlighting takes precedence - ensure high visibility
		// Preserve boundary visibility if it's higher, otherwise use highlight opacity
		final_color.a = max(final_color.a, 0.8); // Minimum 0.8 when highlighted
	}

	if(neuron_selection_has_hit)
	{
		final_color.g = 1.0;
		// Neuron selection takes precedence - ensure high visibility
		final_color.a = max(final_color.a, 0.8); // Minimum 0.8 when selected
	}

	if(neuron_activation_has_hit)
	{
		//final_color.rgb += vec3(0.3, -0.3, 0.3);
		vec3 local_hit_space_mn = local_SVO_space_to_vert_0_1_space(neuron_activation_hit_coordinate_svon, voxel_counts_per_dim, shared_SVO_depth);
		float z_offset_color = local_hit_space_mn.z;
		
		final_color.rgb = vec3(z_offset_color, 0.0, 0.0);
		// Neuron activation takes precedence - ensure visibility
		// Use max to preserve boundary visibility if higher, otherwise ensure minimum for firing neurons
		final_color.a = max(final_color.a, 0.6); // Minimum 0.6 when neurons are active
	}



	final_color.rgb = min(final_color.rgb, vec3(1.0));
	final_color.rgb = max(final_color.rgb, vec3(0.0));
	final_color.a = min(final_color.a, 1.0); // alphas over 1 may cause weird issues
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}
