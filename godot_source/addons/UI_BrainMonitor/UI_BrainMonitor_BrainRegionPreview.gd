extends Node3D
class_name UI_BrainMonitor_BrainRegionPreview
## Shows a translucent shadow preview of where a brain region will be positioned
## Similar to InteractivePreview but specifically designed for dual-plate brain region assemblies

var _brain_region: BrainRegion
var _preview_container: Node3D
var _region_name_label: Label3D

## Sets up the preview with translucent dual plates for the brain region
func setup(brain_region: BrainRegion, initial_FEAGI_position: Vector3i) -> void:
	_brain_region = brain_region
	name = "BrainRegionPreview_" + brain_region.region_ID
	
	# Create preview container
	_preview_container = Node3D.new()
	_preview_container.name = "PreviewAssembly"
	add_child(_preview_container)
	
	# Get I/O areas for sizing (same logic as actual brain region)
	var input_areas = _get_input_areas()
	var output_areas = _get_output_areas()
	
	# Calculate plate sizes
	var input_plate_size = _calculate_plate_size_for_areas(input_areas, "INPUT")
	var output_plate_size = _calculate_plate_size_for_areas(output_areas, "OUTPUT")
	var plate_gap = 1.0  # Gap between plates (same as main brain region)
	var plate_height = 1.0  # Plate height (same as main brain region)
	
	# Handle placeholder plates (5x1x5) for positioning calculations
	var actual_input_width = input_plate_size.x if input_areas.size() > 0 else 5.0
	var actual_output_width = output_plate_size.x if output_areas.size() > 0 else 5.0
	
	# Match main BrainRegion plate style/colors ("plate shadows")
	# Detect conflict state (areas used as both input and output)
	var conflict = false
	var input_ids: Array[StringName] = []
	for a in input_areas:
		input_ids.append(a.cortical_ID)
	for a in output_areas:
		if a.cortical_ID in input_ids:
			conflict = true
			break

	# Base colors (semi-transparent greens) or red-tinted on conflict to match main scene
	var input_color = Color(0.0, 0.6, 0.0, 0.2)
	var output_color = Color(0.0, 0.4, 0.0, 0.2)
	if conflict:
		input_color = Color(0.6, 0.0, 0.0, 0.25)
		output_color = Color(0.6, 0.0, 0.0, 0.25)
	var input_plate
	if input_areas.size() > 0:
		input_plate = _create_visible_preview_plate(input_plate_size, "InputPlatePreview", input_color)
	else:
		input_plate = _create_visible_wireframe_placeholder_plate(Vector3(5.0, 1.0, 5.0), "InputPlatePreview", input_color)
	
	# FRONT-LEFT CORNER positioning (matches main brain region)
	# INPUT PLATE: Front-left corner at preview region coordinates (0,0,0 relative)
	input_plate.position.x = actual_input_width / 2.0  # Half-width to align front-left corner at origin
	input_plate.position.y = plate_height / 2.0  # Half-height to align bottom at origin 
	# Center Z must be NEGATIVE half-depth so the front edge is at parent's Z
	var input_depth = (input_plate_size.z if input_areas.size() > 0 else 5.0)
	input_plate.position.z = -input_depth / 2.0
	_preview_container.add_child(input_plate)
	
	# Create output plate with consistent style
	var output_plate
	if output_areas.size() > 0:
		output_plate = _create_visible_preview_plate(output_plate_size, "OutputPlatePreview", output_color)
	else:
		output_plate = _create_visible_wireframe_placeholder_plate(Vector3(5.0, 1.0, 5.0), "OutputPlatePreview", output_color)
	
	# OUTPUT PLATE: Front-left corner at input_width + gap from preview region front-left corner
	var output_front_left_x = actual_input_width + plate_gap
	output_plate.position.x = output_front_left_x + actual_output_width / 2.0  # Front-left corner + half-width
	output_plate.position.y = plate_height / 2.0  # Half-height to align bottom at origin
	# Center Z must be NEGATIVE half-depth so the front edge is at parent's Z
	var output_depth = (output_plate_size.z if output_areas.size() > 0 else 5.0)
	output_plate.position.z = -output_depth / 2.0
	_preview_container.add_child(output_plate)
	
	# Create preview region name label (positioned consistently with main brain region)
	_region_name_label = Label3D.new()
	_region_name_label.name = "PreviewRegionLabel"
	_region_name_label.text = brain_region.friendly_name + " (PREVIEW)"
	_region_name_label.font_size = 192
	
	# Position label centered between plates and very close to viewer (front edge - small epsilon)
	var center_x = (actual_input_width + plate_gap + actual_output_width) / 2.0
	_region_name_label.position = Vector3(center_x, -3.0, -0.5)
	
	_region_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_region_name_label.outline_render_priority = 1
	_region_name_label.outline_size = 4  # Thicker outline for better visibility
	_region_name_label.modulate = Color(1.0, 1.0, 0.0, 1.0)  # Bright yellow for high visibility
	_region_name_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)  # Black outline for contrast
	_region_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	_preview_container.add_child(_region_name_label)
	
	
	# Set initial position
	update_position_with_new_FEAGI_coordinate(initial_FEAGI_position)
	

## Updates the preview position when coordinates change
func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate: Vector3i) -> void:
	# Convert FEAGI coordinates to Godot space (flip Z-axis)
	var godot_position = Vector3(new_FEAGI_coordinate.x, new_FEAGI_coordinate.y, -new_FEAGI_coordinate.z)
	
	print("  🔍 Parent: %s" % (get_parent().name if get_parent() else "none"))
	print("  🔍 Parent global_position: %s" % (get_parent().global_position if get_parent() else "none"))
	print("  🔍 Parent position: %s" % (get_parent().position if get_parent() else "none"))
	print("  🔍 Parent transform: %s" % (get_parent().transform if get_parent() else "none"))
	
	global_position = godot_position
	
	print("  📍 Current global_position AFTER: %s" % global_position)
	print("  📍 Current position AFTER: %s" % position)
	print("  📍 Difference from expected: %s" % (global_position - godot_position))

## Cleans up the preview
func cleanup() -> void:
	if _preview_container:
		_preview_container.queue_free()
	queue_free()

## Gets input areas for the brain region (same logic as actual brain region)
func _get_input_areas() -> Array[AbstractCorticalArea]:
	var input_areas: Array[AbstractCorticalArea] = []
	
	# Method 1: Check chain links
	for link in _brain_region.input_open_chain_links:
		# Ensure destination is a cortical area before checking/adding
		if link.destination is AbstractCorticalArea:
			var dest_area = link.destination as AbstractCorticalArea
			if dest_area in _brain_region.contained_cortical_areas:
				if not input_areas.has(dest_area):
					input_areas.append(dest_area)
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays)
	for partial_mapping in _brain_region.partial_mappings:
		if partial_mapping.is_region_input:
			var area = partial_mapping.internal_target_cortical_area
			if not input_areas.has(area):
				input_areas.append(area)
	
	# Method 3: Heuristic fallback - only if plausible I/O types found
	if input_areas.is_empty():
		for area in _brain_region.contained_cortical_areas:
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
				if not input_areas.has(area):
					input_areas.append(area)
	
	return input_areas

## Gets output areas for the brain region (same logic as actual brain region)
func _get_output_areas() -> Array[AbstractCorticalArea]:
	var output_areas: Array[AbstractCorticalArea] = []
	
	# Method 1: Check chain links
	for link in _brain_region.output_open_chain_links:
		# Ensure source is a cortical area before checking/adding
		if link.source is AbstractCorticalArea:
			var source_area = link.source as AbstractCorticalArea
			if source_area in _brain_region.contained_cortical_areas:
				if not output_areas.has(source_area):
					output_areas.append(source_area)
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays)
	for partial_mapping in _brain_region.partial_mappings:
		if not partial_mapping.is_region_input:  # Output mapping
			var area = partial_mapping.internal_target_cortical_area
			if not output_areas.has(area):
				output_areas.append(area)
	
	# Method 3: Heuristic fallback - only if plausible I/O types found
	if output_areas.is_empty():
		for area in _brain_region.contained_cortical_areas:
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
				if not output_areas.has(area):
					output_areas.append(area)
	
	return output_areas

## Calculates plate size based on contained areas (same logic as actual brain region)
func _calculate_plate_size_for_areas(areas: Array[AbstractCorticalArea], plate_type: String) -> Vector3:
	var min_plate_size = Vector3(4.0, 1.0, 4.0)  # Minimum plate dimensions
	
	if areas.is_empty():
		return min_plate_size
	
	# Calculate required X width - spread areas along X-axis with gaps
	var total_x_width = 0.0
	var area_gap = 5.0  # Gap between cortical areas - increased to prevent title overlap
	for i in areas.size():
		total_x_width += max(areas[i].dimensions_3D.x, 1.0)  # Minimum 1 unit width per area
		if i < areas.size() - 1:  # Add gap between areas (not after last)
			total_x_width += area_gap
	total_x_width += 2.0  # Add padding on both sides
	
	# Calculate required Z depth - deep enough for largest area
	var max_z_depth = 0.0
	for area in areas:
		max_z_depth = max(max_z_depth, area.dimensions_3D.z)
	max_z_depth = max(max_z_depth, min_plate_size.z)
	
	var plate_size = Vector3(
		max(total_x_width, min_plate_size.x),
		1.0,  # Fixed thickness
		max_z_depth
	)
	
	return plate_size

## Creates a highly visible preview plate with solid appearance
func _create_visible_preview_plate(plate_size: Vector3, plate_name: String, plate_color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = plate_name
	
	# Create box mesh with 1 unit thickness like actual brain region plates
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(plate_size.x, 1.0, plate_size.z)  # Fixed 1.0 thickness for visibility
	mesh_instance.mesh = box_mesh
	
	# Create material that matches main scene plate appearance (semi-transparent, unshaded)
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = plate_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.flags_unshaded = true
	material.flags_transparent = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material.flags_do_not_receive_shadows = true
	material.flags_disable_ambient_light = true
	mesh_instance.material_override = material
	
	return mesh_instance

## Creates a highly visible wireframe placeholder plate for empty input/output areas
func _create_visible_wireframe_placeholder_plate(plate_size: Vector3, plate_name: String, plate_color: Color) -> MeshInstance3D:
	# Create plate mesh instance
	var plate_mesh_instance = MeshInstance3D.new()
	plate_mesh_instance.name = plate_name + "_Wireframe"
	
	# Create array mesh for wireframe
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Define vertices for a box (5x1x5 as specified)
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Box corners (front-left corner at origin)
	var half_x = plate_size.x / 2.0
	var half_y = plate_size.y / 2.0  
	var half_z = plate_size.z / 2.0
	
	# 8 vertices of box (centered for Godot)
	vertices.append(Vector3(-half_x, -half_y, -half_z))  # 0: front-bottom-left
	vertices.append(Vector3(half_x, -half_y, -half_z))   # 1: front-bottom-right
	vertices.append(Vector3(half_x, half_y, -half_z))    # 2: front-top-right
	vertices.append(Vector3(-half_x, half_y, -half_z))   # 3: front-top-left
	vertices.append(Vector3(-half_x, -half_y, half_z))   # 4: back-bottom-left
	vertices.append(Vector3(half_x, -half_y, half_z))    # 5: back-bottom-right
	vertices.append(Vector3(half_x, half_y, half_z))     # 6: back-top-right
	vertices.append(Vector3(-half_x, half_y, half_z))    # 7: back-top-left
	
	# Define wireframe edges (lines connecting box vertices)
	var wireframe_indices = [
		# Front face
		0, 1, 1, 2, 2, 3, 3, 0,
		# Back face  
		4, 5, 5, 6, 6, 7, 7, 4,
		# Connecting edges
		0, 4, 1, 5, 2, 6, 3, 7
	]
	
	for i in wireframe_indices:
		indices.append(i)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	plate_mesh_instance.mesh = array_mesh
	
	# Create highly visible wireframe material for preview
	var wireframe_material = StandardMaterial3D.new()
	wireframe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wireframe_material.albedo_color = plate_color  # Use the bright colors we set
	wireframe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wireframe_material.flags_unshaded = true
	wireframe_material.flags_transparent = true
	wireframe_material.flags_do_not_receive_shadows = true
	wireframe_material.flags_disable_ambient_light = true
	wireframe_material.vertex_color_use_as_albedo = false
	
	# Make wireframe lines thicker and more visible
	wireframe_material.grow_amount = 0.1  # Make lines slightly thicker
	
	# Add slight emission for visibility
	wireframe_material.emission_enabled = true
	wireframe_material.emission = Color(plate_color.r * 0.4, plate_color.g * 0.4, plate_color.b * 0.4)
	
	plate_mesh_instance.material_override = wireframe_material
	
	return plate_mesh_instance
