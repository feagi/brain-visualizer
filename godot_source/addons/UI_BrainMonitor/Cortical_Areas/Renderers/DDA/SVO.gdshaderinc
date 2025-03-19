// Functions related to SVO transversal

#include "res://addons/UI_BrainMonitor/Cortical_Areas/Renderers/DDA/ByteFunctions.gdshaderinc"

#define SVO_MAX_DEPTH 32u // How deep a SVO can go. If you are exceeding this... what are you doing...
#define SVO_LAST_LEAF_IDENTIFIER 16777215u // This value in the "child leaf index offset" section ofa  node read from the SVO tree indicates that the children do not exist as nodes, only as this nodes bitmap reference
#define SVO_NO_LEAF_INDEX 8u // Any function not returning a valid child index (not bitmap) will return this

struct SVOInternalNode {
	uint child_mask;
	uint first_child_node_index;
	uint parent_node_index;
	uint node_index;
};

// Reads a given SVO Node given index
SVOInternalNode read_SVO_node(sampler2D SVO_texture, uint node_index, uint parent_node_index)
{
	SVOInternalNode node;
	ivec2 texture_res = textureSize(SVO_texture, 0);
	ivec2 texture_coordinate = ivec2(int(node_index) % texture_res.x, int(node_index) / texture_res.x);
	vec4 node_pixel = texelFetch(SVO_texture, texture_coordinate, 0); // We actually only have data in the R channel
	uint first_4_bytes = floatBitsToUint(node_pixel.r);

	node.child_mask = first_4_bytes & 0xFFu; // extract first byte as mask
	uint first_child_offset_from_parent = (first_4_bytes >> 8u) & 0x00FFFFFFu;  // read from uint24
	if(first_child_offset_from_parent == SVO_LAST_LEAF_IDENTIFIER) // in the case that the node is a parent of leafs, these child node indexes are not valid, so set them to a known outlier
	{
		node.first_child_node_index = SVO_LAST_LEAF_IDENTIFIER;
	}
	else
	{
		node.first_child_node_index = first_child_offset_from_parent + node_index;
	}
	node.parent_node_index = parent_node_index;
	node.node_index = node_index;
	return node;
}

// Reads a child of an SVONode given 0-7 child index
SVOInternalNode read_child_node(sampler2D SVO_texture, SVOInternalNode parent_node, uint child_index, out bool exists, out bool child_is_parent_of_leaves)
{
	SVOInternalNode node;
	exists = false;
	child_is_parent_of_leaves = false;
	if(is_index_contained_by_bitmask(child_index, parent_node.child_mask))
	{
		uint child_position = count_number_true_bits(parent_node.child_mask & ((1u << child_index) - 1u)); // Since we are skipping nonexistant children
		uint child_node_index = parent_node.first_child_node_index + child_position;
		node = read_SVO_node(SVO_texture, child_node_index,parent_node.node_index);
		child_is_parent_of_leaves = node.first_child_node_index == SVO_LAST_LEAF_IDENTIFIER;
		exists = true;
	}
	return node;
}

// Converts 0-1 mesh space to 0.0 - 1.0 SVO space, but for the size of the Sparse Voxel Octet tree cube, this means any non-2^n mesh will not reach 1.0/
vec3 local_vert_0_1_space_to_SVO_space(vec3 local_vert_space_0_1, vec3 voxel_counts, int SVO_tree_depth)
{
	return (local_vert_space_0_1 * voxel_counts) / vec3(pow(2.0, float(SVO_tree_depth)));
	// NOTE: SVO_tree_depth must be 1 or greater, otherwise weird results will occur
}

// Converts 0-1 mesh space to 0.0 - 1.0 SVO space, but for the size of the Sparse Voxel Octet tree cube, this means any non-2^n mesh will not reach 1.0
vec3 local_SVO_space_to_vert_0_1_space(vec3 local_SVO_space, vec3 voxel_counts, int SVO_tree_depth)
{
	return (local_SVO_space * vec3(float(SVO_tree_depth))) / voxel_counts;
}

// Returns true if a given node is a parent of leaf_nodes
bool is_SVONode_parent_of_leaf(SVOInternalNode node)
{
	return node.first_child_node_index == SVO_LAST_LEAF_IDENTIFIER;
}

// Calculate the max bounds in SVO 0_1 space that any leaf can be in
vec3 get_SVO_0_1_max_bounds(vec3 voxel_counts, int max_SVO_tree_depth)
{
	const float EPSILON = 1e-6;
	vec3 max_as_counts = vec3(exp2(float(max_SVO_tree_depth)));
	return (voxel_counts / max_as_counts) - EPSILON;
}

// Return the size of a single octant in SVO 0-1 scale given the SVO depth
vec3 get_SVO_normalized_octant_size_given_depth(uint depth)
{
	return vec3(pow(2.0,-1.0 * float(depth)));
}

// Retusn the 0-1 corner given the child index
vec3 get_normalized_0_1_corner_position_given_child_index(uint child_index)
{
	return vec3(
			float((child_index & 1u)),
			float(((child_index >> 1u) & 1u)),
			float(((child_index >> 2u) & 1u))
	);
}

vec3 get_normalized_m1_1_corner_position_given_child_index(uint child_index)
{
	return sign(get_normalized_0_1_corner_position_given_child_index(child_index) - 0.5);
}

// Returns true if a given position in SVO 0_1 space is within the allowed bounds
bool is_SVO_position_inside_of_SVO_space(vec3 SVO_checking_position, vec3 SVO_max_bounds_SVO_space)
{
	const float EPSILON = 1e-6;
	if (SVO_checking_position.x < EPSILON || SVO_checking_position.y < EPSILON || SVO_checking_position.z < EPSILON)
	{
		return false;
	}
	if (SVO_checking_position.x > SVO_max_bounds_SVO_space.x || SVO_checking_position.y > SVO_max_bounds_SVO_space.y || SVO_checking_position.z > SVO_max_bounds_SVO_space.z)
	{
		return false;
	}
	return true;
}


// If a given position is within a child node existing children, returns the leaf index. Otherwise, returns SVO_NO_LEAF_INDEX. Note that 'boundary_SVO_space_offset' refers to the total from root offset from the parent node of the given node
uint get_child_index_of_position_from_SVO_node(SVOInternalNode node, uint current_SVO_tree_depth, vec3 XYZ_boundaries_to_check_svon, vec3 checking_SVO_position, out vec3 next_XYZ_boundaries_to_check_svon)
{
	const float EPSILON = 1e-6;
	uint calculated_child_leaf_index = (uint(checking_SVO_position.x > XYZ_boundaries_to_check_svon.x)) | ((uint(checking_SVO_position.y > XYZ_boundaries_to_check_svon.y)) << 1u) | ((uint(checking_SVO_position.z > XYZ_boundaries_to_check_svon.z)) << 2u);
	if (is_index_contained_by_bitmask(calculated_child_leaf_index, node.child_mask))
	{
		vec3 current_octet_size = vec3(exp2(-1.0 * float(current_SVO_tree_depth + 1u)));
		vec3 normalized_m1_1_corner_position = get_normalized_m1_1_corner_position_given_child_index(calculated_child_leaf_index);
		next_XYZ_boundaries_to_check_svon = XYZ_boundaries_to_check_svon + (normalized_m1_1_corner_position * current_octet_size);
		return calculated_child_leaf_index;
	}
	return SVO_NO_LEAF_INDEX;
}
