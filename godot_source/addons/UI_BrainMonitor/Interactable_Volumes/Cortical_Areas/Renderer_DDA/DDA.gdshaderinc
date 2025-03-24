// Functions related to DDA (parsing through voxels)
#define DDA_MAX_ITERATIONS 128


#include "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/SVO.gdshaderinc"

vec3 singleDDAStep(vec3 intial_ray_position_svon,  vec3 normalized_ray_direction, vec3 next_SVO_boundary)
{
	const float EPSILON = 1e-6;
	vec3 t_max = abs((next_SVO_boundary - intial_ray_position_svon) / normalized_ray_direction);
    // Find the smallest tMax (smallest step distance)
	float travel_dist;
    if (t_max.x < t_max.y && t_max.x < t_max.z) {
        travel_dist = t_max.x;
    } else if (t_max.y < t_max.z) {
        travel_dist = t_max.y;
    } else {
        travel_dist = t_max.z;
    }
	return normalized_ray_direction * (travel_dist + EPSILON);
}




// Returns true if ray hits a voxel in the given SVO, and outputs the delta distance in SVO space as well as its normal. Otherwise returns false and the out's are invalid
bool get_01_model_distance_to_voxel_DDA(sampler2D SVO_texture, SVOInternalNode root_node, vec3 SVO_0_1_space_ray_enter_point, vec3 ray_direction_normalized, out vec3 SVO_distance_from_voxel_hit, out vec3 voxel_hit_normal)
{
	const float EPSILON = 1e-6;

	SVOInternalNode node = root_node;
	vec3 current_SVO_boundary_check_svon;
	vec3 possible_next_SVO_boundary_check_svon;
	vec3 SVO_current_point = SVO_0_1_space_ray_enter_point + (ray_direction_normalized * EPSILON); // Slightly inside the volume // TODO ray direciton needs to be modified to SVO space
	vec3 ray_signed_direction = sign(ray_direction_normalized);
	bool node_is_last_before_final_leafs = is_SVONode_parent_of_leaf(node);
	voxel_hit_normal = vec3(0.0);
	SVO_distance_from_voxel_hit = vec3(0.0);

	bool node_exists_UNUSED; // Unused var just neede for out
	uint previous_child_index = SVO_NO_LEAF_INDEX;

	// Loop through DDA
	for (int i = 0; i < DDA_MAX_ITERATIONS; i++)
	{
		// Reset for another transversal through the DDA
		node = root_node;
		current_SVO_boundary_check_svon = vec3(0.5);
		node_is_last_before_final_leafs = false;


		// Loop for navigating the SVO tree at our current location
		for( uint current_SVO_node_depth = 1u; current_SVO_node_depth < SVO_MAX_DEPTH; current_SVO_node_depth++)
		{
			uint ray_entering_child_index = get_child_index_of_position_from_SVO_node(node, current_SVO_node_depth, current_SVO_boundary_check_svon, SVO_current_point, possible_next_SVO_boundary_check_svon); // NOTE: Writes to possible_next_SVO_boundary_check_svon, but is only valid if ray_entering_child_index != SVO_NO_LEAF_INDEX
			if (ray_entering_child_index != SVO_NO_LEAF_INDEX) // if the above returns SVO_NO_LEAF_INDEX, then the entering child index does not have a valid node
			{
				previous_child_index = ray_entering_child_index;
				// child node hit, was it a leaf?
				if(node_is_last_before_final_leafs)
				{
					// HIT end leaf!
					SVO_distance_from_voxel_hit = SVO_current_point - SVO_0_1_space_ray_enter_point; // TODO convert this?
					return true;
				}
				// HIT node!
				// We have more of the SVO tree to transverse down
				node = read_child_node(SVO_texture, node, ray_entering_child_index, node_exists_UNUSED, node_is_last_before_final_leafs);
				current_SVO_boundary_check_svon = possible_next_SVO_boundary_check_svon;
			}
			else
			{
				SVO_current_point += singleDDAStep(SVO_current_point, ray_direction_normalized, current_SVO_boundary_check_svon);
				if(!(is_SVO_position_inside_of_SVO_space(SVO_current_point, vec3(1,1,1)))) // TODO replace max size with actual SVO size
				{
					return false;
				}
				break;
			}
		}

	}

	return false; // no hit at all for the entire DDA ray
}
