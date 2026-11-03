shader_type spatial;
render_mode unshaded;

// Draws a cortical area whose activity is streamed by a feagi-core server as one bit per voxel.
// The bits of the whole brain are in one texture every area's material shares (see
// FEAGIBitVisualization.gd), and this area's start at read_start_byte_index. Within an area they run x first, then y, then z (in FEAGI
// space, whose z is flipped against the mesh's), least significant bit of each byte first.
// Highlighting and selection use the same SVOs as WebGLRayMarch.gdshader.

#include "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/SVO.gdshaderinc"
#include "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/ByteFunctions.gdshaderinc"
#include "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/DDA.gdshaderinc"

// Most voxels a ray can cross before giving up
#define BIT_DDA_MAX_STEPS 512

// Bit data of the whole brain, as an R8 texture filled row by row. Shared by every area
uniform sampler2D feagi_bit_visualization_bytes : filter_nearest, hint_default_black;

uniform int voxel_count_x : hint_range(1, 2500) = 3;
uniform int voxel_count_y : hint_range(1, 2500) = 3;
uniform int voxel_count_z : hint_range(1, 2500) = 3;
// Byte index this area's bits start at in feagi_bit_visualization_bytes. Negative when the server
// gave none, which draws no activity
uniform int read_start_byte_index = -1;
uniform float voxel_opacity : hint_range(0.0, 1.0) = 0.15;
uniform vec3 voxel_color : source_color = vec3(0.0, 0.2, 0.0);
uniform int shared_SVO_depth : hint_range(1, SVO_MAX_DEPTH);
uniform float activation_min_red : hint_range(0.0, 1.0) = 0.3; // Red intensity of the furthest back firing voxels
uniform float edge_thickness : hint_range(0.001, 0.05) = 0.008;
uniform sampler2D highlight_SVO : hint_default_black;
uniform sampler2D selection_SVO : hint_default_black;

varying vec3 local_vert_space_m05_05; // -0.5 -> 0.5 across the mesh surface of the cube

// Whether the bit of the voxel at mesh space cell [param cell] is on
bool is_voxel_on(ivec3 cell)
{
	if (read_start_byte_index < 0)
	{
		return false;
	}
	int feagi_z = voxel_count_z - 1 - cell.z;
	int bit_index = cell.x + voxel_count_x * (cell.y + voxel_count_y * feagi_z);
	int byte_index = read_start_byte_index + (bit_index >> 3);
	ivec2 texture_size = textureSize(feagi_bit_visualization_bytes, 0);
	ivec2 texel = ivec2(byte_index % texture_size.x, byte_index / texture_size.x);
	if (texel.y >= texture_size.y)
	{
		return false;
	}
	uint byte_value = uint(texelFetch(feagi_bit_visualization_bytes, texel, 0).r * 255.0 + 0.5);
	return ((byte_value >> uint(bit_index & 7)) & 1u) != 0u;
}

// Walks the voxels a ray crosses (Amanatides & Woo), from where it enters the mesh. Positions are
// in voxel space (0 -> voxel count per axis). Returns true and the first voxel whose bit is on, if any
bool get_first_on_voxel(vec3 entry_voxel_space, vec3 direction_voxel_space, out ivec3 hit_cell)
{
	const float EPSILON = 1e-4;
	ivec3 counts = ivec3(voxel_count_x, voxel_count_y, voxel_count_z);
	ivec3 cell = clamp(ivec3(floor(entry_voxel_space + direction_voxel_space * EPSILON)), ivec3(0), counts - 1);
	ivec3 step_direction = ivec3(sign(direction_voxel_space));
	vec3 safe_direction = mix(direction_voxel_space, vec3(EPSILON), equal(direction_voxel_space, vec3(0.0)));
	vec3 t_delta = abs(1.0 / safe_direction);
	vec3 next_boundary = vec3(cell) + max(vec3(step_direction), vec3(0.0));
	vec3 t_max = (next_boundary - entry_voxel_space) / safe_direction;
	hit_cell = ivec3(0);

	for (int i = 0; i < BIT_DDA_MAX_STEPS; i++)
	{
		if (is_voxel_on(cell))
		{
			hit_cell = cell;
			return true;
		}
		if (t_max.x < t_max.y && t_max.x < t_max.z)
		{
			cell.x += step_direction.x;
			t_max.x += t_delta.x;
		}
		else if (t_max.y < t_max.z)
		{
			cell.y += step_direction.y;
			t_max.y += t_delta.y;
		}
		else
		{
			cell.z += step_direction.z;
			t_max.z += t_delta.z;
		}
		if (any(lessThan(cell, ivec3(0))) || any(greaterThanEqual(cell, counts)))
		{
			return false;
		}
	}
	return false;
}

void vertex()
{
	local_vert_space_m05_05 = VERTEX;
}

void fragment()
{
	vec3 voxel_counts_per_dim = vec3(float(voxel_count_x), float(voxel_count_y), float(voxel_count_z));
	vec3 ray_origin_m = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1)).xyz;
	vec3 ray_direction_mn = normalize(local_vert_space_m05_05 - ray_origin_m);
	vec3 mesh_surface_position_mn = local_vert_space_m05_05 + vec3(0.5);

	// Activity, from the bits
	ivec3 activation_hit_cell;
	bool activation_has_hit = get_first_on_voxel(mesh_surface_position_mn * voxel_counts_per_dim, ray_direction_mn * voxel_counts_per_dim, activation_hit_cell);

	// Highlighting and selection, from their SVOs
	vec3 ray_direction_svon = normalize(local_vert_0_1_space_to_SVO_space(ray_direction_mn, voxel_counts_per_dim, shared_SVO_depth));
	vec3 mesh_surface_position_svon = local_vert_0_1_space_to_SVO_space(mesh_surface_position_mn, voxel_counts_per_dim, shared_SVO_depth);
	vec3 unused_offset_svon;
	vec3 unused_normal_svon;
	vec3 unused_coordinate_svon;
	SVOInternalNode highlight_root_SVO = read_SVO_node(highlight_SVO, 0u, 0u);
	bool highlight_has_hit = get_01_model_distance_to_voxel_DDA(highlight_SVO, highlight_root_SVO, mesh_surface_position_svon, ray_direction_svon, unused_offset_svon, unused_normal_svon, unused_coordinate_svon);
	SVOInternalNode selection_root_SVO = read_SVO_node(selection_SVO, 0u, 0u);
	bool selection_has_hit = get_01_model_distance_to_voxel_DDA(selection_SVO, selection_root_SVO, mesh_surface_position_svon, ray_direction_svon, unused_offset_svon, unused_normal_svon, unused_coordinate_svon);

	// A faint outer shell, with solid edges where faces meet
	vec3 distance_to_faces = vec3(0.5) - abs(local_vert_space_m05_05);
	float min_distance_to_face = min(min(distance_to_faces.x, distance_to_faces.y), distance_to_faces.z);
	float shell_mask = 1.0 - smoothstep(0.0, 0.02, min_distance_to_face);
	vec4 final_color = vec4(voxel_color, voxel_opacity * shell_mask * 0.25);
	int faces_close_to = 0;
	if (distance_to_faces.x <= edge_thickness) faces_close_to++;
	if (distance_to_faces.y <= edge_thickness) faces_close_to++;
	if (distance_to_faces.z <= edge_thickness) faces_close_to++;
	if (faces_close_to >= 2)
	{
		final_color = vec4(0.45, 0.5, 0.6, max(final_color.a, 0.6));
	}

	// Firing is drawn over selection and highlighting, so interacting never hides it
	if (activation_has_hit)
	{
		float depth = (float(activation_hit_cell.z) + 0.5) / voxel_counts_per_dim.z; // 0 at the back, 1 at the front
		final_color = vec4(mix(activation_min_red, 1.0, depth), 0.0, 0.0, max(final_color.a, 0.85));
	}
	else if (selection_has_hit)
	{
		final_color.g = 1.0;
		final_color.a = max(final_color.a, 0.3);
	}
	else if (highlight_has_hit)
	{
		final_color.b = 1.0;
		final_color.a = max(final_color.a, 0.8);
	}

	ALBEDO = clamp(final_color.rgb, vec3(0.0), vec3(1.0));
	ALPHA = clamp(final_color.a, 0.0, 1.0);
}
