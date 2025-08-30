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
	var plate_spacing = 1.0
	
	# Create translucent input plate (dark green)
	var input_plate = _create_translucent_plate(input_plate_size, "InputPlatePreview", Color(0.0, 0.4, 0.0, 0.5))
	input_plate.position.x = -(input_plate_size.x / 2.0 + plate_spacing / 2.0)
	input_plate.position.y = -1.0
	_preview_container.add_child(input_plate)
	
	# Create translucent output plate (dark blue)  
	var output_plate = _create_translucent_plate(output_plate_size, "OutputPlatePreview", Color(0.0, 0.0, 0.4, 0.5))
	output_plate.position.x = output_plate_size.x / 2.0 + plate_spacing / 2.0
	output_plate.position.y = -1.0
	_preview_container.add_child(output_plate)
	
	# Create preview region name label
	_region_name_label = Label3D.new()
	_region_name_label.name = "PreviewRegionLabel"
	_region_name_label.text = brain_region.friendly_name + " (PREVIEW)"
	_region_name_label.font_size = 192
	_region_name_label.position = Vector3(0.0, -3.0, 0.0)
	_region_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_region_name_label.outline_render_priority = 1
	_region_name_label.outline_size = 2
	_region_name_label.modulate = Color(1.0, 1.0, 1.0, 0.7)  # Translucent white
	_region_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	_preview_container.add_child(_region_name_label)
	
	# Set initial position
	update_position_with_new_FEAGI_coordinate(initial_FEAGI_position)
	
	print("🔮 Brain region preview setup completed for: %s" % brain_region.friendly_name)

## Updates the preview position when coordinates change
func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate: Vector3i) -> void:
	# Convert FEAGI coordinates to Godot space (flip Z-axis)
	var godot_position = Vector3(new_FEAGI_coordinate.x, new_FEAGI_coordinate.y, -new_FEAGI_coordinate.z)
	global_position = godot_position

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
		if link.destination in _brain_region.contained_cortical_areas:
			if not input_areas.has(link.destination):
				input_areas.append(link.destination)
	
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
		if link.source in _brain_region.contained_cortical_areas:
			if not output_areas.has(link.source):
				output_areas.append(link.source)
	
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

## Creates a translucent plate mesh
func _create_translucent_plate(plate_size: Vector3, plate_name: String, plate_color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = plate_name
	
	# Create box mesh
	var box_mesh = BoxMesh.new()
	box_mesh.size = plate_size
	mesh_instance.mesh = box_mesh
	
	# Create translucent material
	var material = StandardMaterial3D.new()
	material.albedo_color = plate_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.flags_transparent = true
	material.flags_unshaded = true  # Makes it glow slightly
	mesh_instance.material_override = material
	
	return mesh_instance
