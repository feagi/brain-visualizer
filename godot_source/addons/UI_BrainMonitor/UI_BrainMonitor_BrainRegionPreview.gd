extends Node3D
class_name UI_BrainMonitor_BrainRegionPreview
## Shows a translucent shadow preview of where a brain region will be positioned
## Similar to InteractivePreview but specifically designed for dual-plate brain region assemblies

var _brain_region: BrainRegion
var _preview_container: Node3D
var _region_name_label: Label3D

signal user_moved_preview(new_FEAGI_space_position: Vector3i)

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
	global_position = godot_position
	user_moved_preview.emit(new_FEAGI_coordinate)

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

## Creates a highly visible placeholder using 12 "edge rods" (thick borders) for empty input/output plates
func _create_visible_wireframe_placeholder_plate(plate_size: Vector3, plate_name: String, plate_color: Color) -> MeshInstance3D:
	# Parent node will act as a container; children will be 12 BoxMesh edge rods
	var plate_mesh_instance = MeshInstance3D.new()
	plate_mesh_instance.name = plate_name + "_Wireframe"
	plate_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Half dimensions for positioning
	var half_x = plate_size.x / 2.0
	var half_y = plate_size.y / 2.0
	var half_z = plate_size.z / 2.0
	
	# Material: unshaded, emissive, opaque for strong visibility
	var edge_material = StandardMaterial3D.new()
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.albedo_color = Color(plate_color.r, plate_color.g, plate_color.b, 1.0)
	edge_material.flags_unshaded = true
	edge_material.flags_transparent = false
	edge_material.flags_do_not_receive_shadows = true
	edge_material.flags_disable_ambient_light = true
	edge_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	edge_material.emission_enabled = true
	edge_material.emission = Color(plate_color.r * 0.6, plate_color.g * 0.6, plate_color.b * 0.6)
	
	# Thickness of edge rods
	var edge_thickness: float = 0.25
	# 4 edges along X (front/back, top/bottom)
	for y in [-half_y, half_y]:
		for z in [-half_z, half_z]:
			var rod_x = MeshInstance3D.new()
			rod_x.name = "Edge_X_%s_%s" % [str(y), str(z)]
			var bm_x = BoxMesh.new()
			bm_x.size = Vector3(plate_size.x, edge_thickness, edge_thickness)
			rod_x.mesh = bm_x
			rod_x.position = Vector3(0.0, y, z)
			rod_x.material_override = edge_material
			rod_x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plate_mesh_instance.add_child(rod_x)
	# 4 edges along Y (front/back, left/right)
	for z in [-half_z, half_z]:
		for x in [-half_x, half_x]:
			var rod_y = MeshInstance3D.new()
			rod_y.name = "Edge_Y_%s_%s" % [str(x), str(z)]
			var bm_y = BoxMesh.new()
			bm_y.size = Vector3(edge_thickness, plate_size.y, edge_thickness)
			rod_y.mesh = bm_y
			rod_y.position = Vector3(x, 0.0, z)
			rod_y.material_override = edge_material
			rod_y.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plate_mesh_instance.add_child(rod_y)
	# 4 edges along Z (left/right, top/bottom)
	for y in [-half_y, half_y]:
		for x in [-half_x, half_x]:
			var rod_z = MeshInstance3D.new()
			rod_z.name = "Edge_Z_%s_%s" % [str(x), str(y)]
			var bm_z = BoxMesh.new()
			bm_z.size = Vector3(edge_thickness, edge_thickness, plate_size.z)
			rod_z.mesh = bm_z
			rod_z.position = Vector3(x, y, 0.0)
			rod_z.material_override = edge_material
			rod_z.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plate_mesh_instance.add_child(rod_z)
	
	return plate_mesh_instance
