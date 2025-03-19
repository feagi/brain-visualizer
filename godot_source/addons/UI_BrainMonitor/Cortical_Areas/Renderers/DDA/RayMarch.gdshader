shader_type spatial;
//render_mode unshaded; // for debugging
render_mode unshaded;

#include "res://addons/UI_BrainMonitor/Cortical_Areas/Renderers/DDA/SVO.gdshaderinc"
#include "res://addons/UI_BrainMonitor/Cortical_Areas/Renderers/DDA/ByteFunctions.gdshaderinc"
#include "res://addons/UI_BrainMonitor/Cortical_Areas/Renderers/DDA/DDA.gdshaderinc"

#define MAX_DISTANCE 1000.0 // maximum distance to ray march (float)
#define ERROR_COLOR vec4(1.0,0.2,0.6,1)


uniform int voxel_count_x : hint_range(1, 2500) = 3;
uniform int voxel_count_y : hint_range(1, 2500) = 3;
uniform int voxel_count_z : hint_range(1, 2500) = 3;
uniform float voxel_opacity : hint_range(0.0, 1.0) = 0.2;
uniform vec3 voxel_color : source_color = vec3(0.0, 0.2, 0.0);
uniform int shared_SVO_depth: hint_range(1, SVO_MAX_DEPTH); // All SVOs use the same depth factor. This is the depth of the SVO tree (root included)
uniform sampler2D activation_SVO : hint_default_black;

varying vec3 local_vert_space_m05_05; // Goes from -0.5 -> 0.5  across the actual mesh surface of the cube
//varying vec3 local_vert_space_0_1; // Goes from 0.0 -> 1.0 across the actual mesh surface of the cube
//varying vec3 shared_SVO_vert_space; //  0.0 - 1.0, but for the size of the Sparse Voxel Octet tree cube, this means any non-2^n mesh will not reach 1.0
varying vec3 individual_voxel_size; // Normalized (0 - 1.0) size of each voxel (mesh wise)

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
    vec3 ray_origin_m = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1)).xyz; // CORRECT
    vec3 ray_direction_mn = normalize(local_vert_space_m05_05 - ray_origin_m); // CORRECT
	vec3 ray_direction_svon = normalize(local_vert_0_1_space_to_SVO_space(ray_direction_mn, voxel_counts_per_dim, shared_SVO_depth)); // ?

	// Get Space variations
	vec3 mesh_surface_position_mn = local_vert_space_m05_05 + vec3(0.5);
	vec3 mesh_surface_position_svon = local_vert_0_1_space_to_SVO_space(mesh_surface_position_mn, voxel_counts_per_dim, shared_SVO_depth);


	/// Calculate SVO hits
	// Neuron Activation SVO
	SVOInternalNode neuron_activation_root_SVO = read_SVO_node(activation_SVO, 0u, 0u);
	vec3 neuron_activation_hit_normal_svon;
	vec3 neuron_activation_hit_offset_svon;
	bool neuron_activation_has_hit = get_01_model_distance_to_voxel_DDA(activation_SVO, neuron_activation_root_SVO, mesh_surface_position_svon, ray_direction_svon, neuron_activation_hit_offset_svon, neuron_activation_hit_normal_svon);







	/// Calculate wall count color for "background"
	ivec3 number_walls_per_direction = get_number_wall_intersections(local_vert_space_m05_05, individual_voxel_size, ray_direction_mn); // TODO -> floating point error causing errors counting, investigate
	float wall_transparency = (float(number_walls_per_direction.x) * voxel_opacity) + (float(number_walls_per_direction.y) * voxel_opacity) + (float(number_walls_per_direction.z) * voxel_opacity); // TODO this looks bad



	/// Calculate final pixel color
	final_color.a = wall_transparency;
	if(neuron_activation_has_hit)
	{
		final_color.rgb = vec3(0.0);
		final_color.a = 1.0;
	}



	final_color.rgb = min(final_color.rgb, vec3(1.0));
	final_color.rgb = max(final_color.rgb, vec3(0.0));
	final_color.a = min(final_color.a, 1.0); // alphas over 1 may cause weird issues
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}
