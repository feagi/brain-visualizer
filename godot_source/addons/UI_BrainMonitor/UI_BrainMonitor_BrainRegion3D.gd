extends Node3D
class_name UI_BrainMonitor_BrainRegion3D
## 3D visualization component for brain regions
## Creates a 3D frame with input areas on left, output areas on right

signal region_double_clicked(brain_region: BrainRegion)
signal region_hover_changed(brain_region: BrainRegion, is_hovered: bool)

const FRAME_THICKNESS: float = 0.2
const FRAME_PADDING: Vector3 = Vector3(1.0, 1.0, 0.5)
const INPUT_OUTPUT_SPACING: float = 2.0
const CORTICAL_AREA_SPACING: float = 1.5

# IO Plate Configuration Variables - easily tunable
const AREA_BUFFER_DISTANCE: float = 5.0      # Distance between cortical areas on same plate
const PLATE_SIDE_MARGIN: float = 2.0         # Margin on left/right sides of plate  
const PLATE_FRONT_BACK_MARGIN: float = 2.0   # Margin on front/back of plate
const PLATE_HEIGHT: float = 1.0              # Constant height of all plates
const PLATE_GAP: float = 1.0                 # Gap between input and output plates
const AREA_ABOVE_PLATE_GAP: float = 3.0      # Gap between plate top and area bottom
const PLACEHOLDER_PLATE_SIZE: Vector3 = Vector3(5.0, 1.0, 5.0)  # Size for empty plate placeholders

var representing_region: BrainRegion:
	get: return _representing_region

var _representing_region: BrainRegion
var _frame_container: Node3D
var _frame_collision: StaticBody3D
var _input_areas_container: Node3D
var _output_areas_container: Node3D
var _region_name_label: Label3D
var _cortical_area_visualizations: Dictionary[StringName, UI_BrainMonitor_CorticalArea] = {}
var _generated_io_coordinates: Dictionary = {}  # Stores the generated I/O coordinates

## Logs dimensions of all I/O cortical areas for plate sizing calculations
func _log_io_area_dimensions(brain_region: BrainRegion) -> void:
	var input_areas = _get_input_cortical_areas_for_logging(brain_region)
	var output_areas = _get_output_cortical_areas_for_logging(brain_region)
	
	print("    📊 Found %d inputs + %d outputs = %d total I/O areas" % [input_areas.size(), output_areas.size(), input_areas.size() + output_areas.size()])
	# Detailed area dimensions logged only if needed for debugging:
	# for area in input_areas: print("      🔵 %s: dims %s, coords %s" % [area.cortical_ID, area.dimensions_3D, area.coordinates_3D])
	# for area in output_areas: print("      🔴 %s: dims %s, coords %s" % [area.cortical_ID, area.dimensions_3D, area.coordinates_3D])

## Helper methods for logging (using same logic as visualization methods)
func _get_input_cortical_areas_for_logging(brain_region: BrainRegion) -> Array[AbstractCorticalArea]:
	var input_areas: Array[AbstractCorticalArea] = []
	
	# Use same logic as main methods but without verbose logging  
	for link: ConnectionChainLink in brain_region.input_open_chain_links:
		if link.destination and link.destination is AbstractCorticalArea:
			var area = link.destination as AbstractCorticalArea
			if area not in input_areas:
				input_areas.append(area)
	
	# Fallback to IPU types and naming heuristics if no chain links
	if brain_region.input_open_chain_links.size() == 0:
		for area: AbstractCorticalArea in brain_region.contained_cortical_areas:
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU and area not in input_areas:
				input_areas.append(area)
		
		if input_areas.size() == 0 and brain_region.contained_cortical_areas.size() == 2:
			for area in brain_region.contained_cortical_areas:
				var area_id = area.cortical_ID.to_lower()
				if "rig" in area_id or "right" in area_id or "input" in area_id or "in" in area_id:
					input_areas.append(area)
					break
			if input_areas.size() == 0:
				input_areas.append(brain_region.contained_cortical_areas[0])
	
	return input_areas

func _get_output_cortical_areas_for_logging(brain_region: BrainRegion) -> Array[AbstractCorticalArea]:
	var output_areas: Array[AbstractCorticalArea] = []
	
	# Use same logic as main methods but without verbose logging
	for link: ConnectionChainLink in brain_region.output_open_chain_links:
		if link.source and link.source is AbstractCorticalArea:
			var area = link.source as AbstractCorticalArea
			if area not in output_areas:
				output_areas.append(area)
	
	# Fallback to OPU types and naming heuristics if no chain links
	if brain_region.output_open_chain_links.size() == 0:
		for area: AbstractCorticalArea in brain_region.contained_cortical_areas:
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU and area not in output_areas:
				output_areas.append(area)
		
		if output_areas.size() == 0 and brain_region.contained_cortical_areas.size() == 2:
			for area in brain_region.contained_cortical_areas:
				var area_id = area.cortical_ID.to_lower()
				if "lef" in area_id or "left" in area_id or "output" in area_id or "out" in area_id:
					output_areas.append(area)
					break
	
	return output_areas

## Generates new coordinates for input/output areas relative to brain region position
## Areas are positioned ABOVE the plates with consistent Y and Z starting points:
## - Y: plate_top_y (1.5) + area_height/2.0 (shifted up by 2 from original plate surface)  
## - Z: ALL areas have IDENTICAL front edge at brain region Z coordinate (no offset)
##   In FEAGI coordinate system: +Z goes DEEPER into scene, so plates extend from front_edge toward +Z
func generate_io_coordinates_for_brain_region(brain_region: BrainRegion) -> Dictionary:
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	
	# FEAGI coordinates = front-left corner (lowest x,y,z) - NO extra offsets
	print("🎯 Generating coordinates: %d inputs, %d outputs for region '%s'" % [input_areas.size(), output_areas.size(), brain_region.friendly_name])
	print("    📍 FEAGI brain region coordinates = front-left corner of input plate: %s" % brain_region.coordinates_3D)
	print("    🎯 All positioning relative to this front-left corner (lowest x,y,z)")
	
	var result = {
		"region_id": brain_region.region_ID,
		"region_coordinates": brain_region.coordinates_3D,
		"inputs": [],
		"outputs": []
	}
	
	# Calculate base positioning - brain region coordinates are the LOWEST corner (minimum x,y,z)
	var region_origin = Vector3(brain_region.coordinates_3D)  # Starting point, not center
	
	# FRONT-LEFT CORNER POSITIONING - Everything uses lowest x,y,z coordinates
	# Calculate plate sizes for positioning
	var input_plate_size = _calculate_plate_size_for_areas(input_areas, "INPUT")
	var output_plate_size = _calculate_plate_size_for_areas(output_areas, "OUTPUT")
	
	# INPUT PLATE: Front-left corner at brain region coordinates (0,0,0 relative)
	# Input areas start at: region coordinates + margin
	var input_start_x = PLATE_SIDE_MARGIN  # Margin from left edge
	var input_start_y = AREA_ABOVE_PLATE_GAP  # Margin from bottom edge  
	var input_start_z = 0.0  # No Z offset from region front edge
	
	# OUTPUT PLATE: Front-left corner at input_width + gap from region
	# Output areas start at: output plate front-left corner + margin
	var output_plate_x = input_plate_size.x + PLATE_GAP
	var output_start_x = output_plate_x + PLATE_SIDE_MARGIN
	var output_start_y = AREA_ABOVE_PLATE_GAP
	var output_start_z = 0.0  # Same Z as input (no offset from region front edge)
	
	print("  📥 Processing %d INPUT areas (front-left corner positioning):" % input_areas.size())
	var current_input_x = input_start_x  # Start at plate front-left + margin
	for i in input_areas.size():
		var area = input_areas[i]
		var area_size = Vector3(area.dimensions_3D)
		
		# Position area: FRONT-LEFT CORNER positioning (lowest x,y,z)
		var area_front_left_x = current_input_x
		var area_front_left_y = input_start_y
		var area_front_left_z = input_start_z
		
		var new_position = region_origin + Vector3(area_front_left_x, area_front_left_y, area_front_left_z)
		
		# Move to next area position: current_x + area_width + buffer
		current_input_x += area_size.x + AREA_BUFFER_DISTANCE
		
		var input_data = {
			"area_id": area.cortical_ID,
			"area_type": area.type_as_string,
			"original_coordinates": area.coordinates_3D,
			"new_coordinates": Vector3i(new_position)
		}
		result.inputs.append(input_data)
		
		print("    🔵 INPUT: %s (%s) - dims=%s" % [area.cortical_ID, area.type_as_string, area_size])
		print("      📍 Original coordinates: %s" % area.coordinates_3D)
		print("      📍 NEW coordinates: %s" % Vector3i(new_position))
		print("      🎯 FRONT-EDGE Z: %.1f (same as brain region Z)" % brain_region.coordinates_3D.z)
		print("      🎯 CENTER Z: %.1f (front_edge + depth/2)" % new_position.z)
		print("      📐 Offset from region: %s" % (new_position - region_origin))
	
	print("  📤 Processing %d OUTPUT areas (front-left corner positioning):" % output_areas.size())
	var current_output_x = output_start_x  # Start at output plate front-left + margin
	for i in output_areas.size():
		var area = output_areas[i]
		var area_size = Vector3(area.dimensions_3D)
		
		# Position area: FRONT-LEFT CORNER positioning (lowest x,y,z)
		var area_front_left_x = current_output_x
		var area_front_left_y = output_start_y
		var area_front_left_z = output_start_z
		
		var new_position = region_origin + Vector3(area_front_left_x, area_front_left_y, area_front_left_z)
		
		# Move to next area position: current_x + area_width + buffer
		current_output_x += area_size.x + AREA_BUFFER_DISTANCE
		
		var output_data = {
			"area_id": area.cortical_ID,
			"area_type": area.type_as_string, 
			"original_coordinates": area.coordinates_3D,
			"new_coordinates": Vector3i(new_position)
		}
		result.outputs.append(output_data)
		
		print("    🔴 OUTPUT: %s (%s) - dims=%s" % [area.cortical_ID, area.type_as_string, area_size])
		print("      📍 Original coordinates: %s" % area.coordinates_3D)
		print("      📍 NEW coordinates: %s" % Vector3i(new_position))
		print("      🎯 FRONT-EDGE Z: %.1f (same as brain region Z)" % brain_region.coordinates_3D.z)
		print("      🎯 CENTER Z: %.1f (front_edge + depth/2)" % new_position.z)
		print("      📐 Offset from region: %s" % (new_position - region_origin))
	
	print("🏁 Coordinate generation complete for region: %s" % brain_region.friendly_name)
	print("  📊 Generated %d input + %d output coordinates" % [input_areas.size(), output_areas.size()])
	print("  ✅ === FRONT-EDGE POSITIONING SUMMARY ===")
	print("    🟢 Input areas: FRONT-EDGE Z=%.1f (brain region front-left corner)" % brain_region.coordinates_3D.z)  
	print("    🔵 Output areas: FRONT-EDGE Z=%.1f (brain region front-left corner)" % brain_region.coordinates_3D.z)
	print("    🎯 ALL I/O areas have IDENTICAL front edge at Z=%.1f" % brain_region.coordinates_3D.z)
	
	return result

## DEBUG: Manually check label positions
func debug_label_positions() -> void:
	print("🔍 MANUAL LABEL DEBUG CHECK:")
	if _representing_region:
		print("    🧠 Brain region FEAGI coordinates: %s" % _representing_region.coordinates_3D)
		print("    🧠 Brain region global_position: %s" % global_position)
	else:
		print("    ❌ No representing region!")
		
	if _region_name_label:
		print("    🏷️ Label exists: YES")
		print("    🏷️ Label local position: %s" % _region_name_label.position)
		print("    🏷️ Label global_position: %s" % _region_name_label.global_position)
		print("    🏷️ Label parent: %s" % _region_name_label.get_parent().name)
	else:
		print("    ❌ No region name label found!")
		
	print("    📦 Total BrainRegion3D children: %d" % get_child_count())
	for i in get_child_count():
		var child = get_child(i)
		print("        - Child %d: %s (type: %s)" % [i, child.name, child.get_class()])

## Returns the generated I/O coordinates for this brain region
func get_generated_io_coordinates() -> Dictionary:
	return _generated_io_coordinates

## Setup the 3D brain region visualization
func setup(brain_region: BrainRegion) -> void:
	print("🏗️ BrainRegion3D Setup started for region: %s" % brain_region.friendly_name)
	print("  📊 Region info:")
	print("    - Region ID: %s" % brain_region.region_ID)
	print("    - 3D Coordinates: %s" % brain_region.coordinates_3D)
	print("    - Contains %d cortical areas" % brain_region.contained_cortical_areas.size())
	print("    - Contains %d subregions" % brain_region.contained_regions.size())
	print("    - Has %d input chain links" % brain_region.input_open_chain_links.size())
	print("    - Has %d output chain links" % brain_region.output_open_chain_links.size())
	
	print("  📏 Analyzing I/O cortical area dimensions for plate sizing:")
	_log_io_area_dimensions(brain_region)
	
	# 🚨 CRITICAL FIX: Set _representing_region BEFORE coordinate generation 
	# because I/O detection functions depend on it!
	_representing_region = brain_region
	
	print("  🎯 Generating new coordinates for I/O areas:")
	_generated_io_coordinates = generate_io_coordinates_for_brain_region(brain_region)
	name = "BrainRegion3D_" + brain_region.region_ID
	
	# Create frame structure
	_create_3d_plate()
	_create_containers()
	
	# Populate with cortical areas
	print("  👥 Populating cortical areas...")
	_populate_cortical_areas()
	
	# Connect to region signals for dynamic updates
	_representing_region.cortical_area_added_to_region.connect(_on_cortical_area_added)
	_representing_region.cortical_area_removed_from_region.connect(_on_cortical_area_removed)
	_representing_region.coordinates_3D_updated.connect(_update_position)
	_representing_region.friendly_name_updated.connect(_update_frame_label)
	
	# Set initial position using FEAGI coordinates
	print("  📍 Setting position...")
	var coords = _representing_region.coordinates_3D
	print("  🔍 DEBUG SETUP: Brain region coordinates from object: %s" % coords)
	var distance_from_origin = Vector3(coords).length()
	
	if distance_from_origin > 100.0:
		print("  ⚠️  WARNING: Brain region positioned very far from origin!")
		print("    📍 Coordinates: %s" % coords)
		print("    📏 Distance from origin: %.1f units" % distance_from_origin)
		print("    💡 This might make the brain region invisible in the camera view.")
		print("    💡 Try moving the camera or adjusting the brain region coordinates.")
	
	print("  🚀 DEBUG SETUP: About to call _update_position with coords: %s" % coords)
	_update_position(_representing_region.coordinates_3D)
	print("  ✅ DEBUG SETUP: _update_position call completed")
	print("🏁 BrainRegion3D Setup completed for region: %s" % _representing_region.friendly_name)

## Custom dimension update handler for I/O cortical areas on brain region plates
## Updates dimensions without overriding brain region positioning
func _on_io_cortical_area_dimensions_changed(new_dimensions: Vector3i, cortical_id: String) -> void:
	print("🔧 Brain region handling dimension update for I/O area %s: %s" % [cortical_id, new_dimensions])
	
	# Find the cortical visualization using the ID
	var cortical_viz = _cortical_area_visualizations.get(cortical_id)
	if cortical_viz == null:
		push_error("Brain region dimension update: Could not find visualization for area %s" % cortical_id)
		return
	
	# Update DDA renderer dimensions (but preserve positioning)
	if cortical_viz._dda_renderer != null:
		# Update scale and shader parameters but NOT position
		cortical_viz._dda_renderer._dimensions = new_dimensions
		if cortical_viz._dda_renderer._static_body != null:
			cortical_viz._dda_renderer._static_body.scale = new_dimensions
			# print("      📏 Updated DDA renderer scale: %s" % new_dimensions)  # Suppressed - too frequent
		
		# Update shader parameters
		if cortical_viz._dda_renderer._DDA_mat != null:
			cortical_viz._dda_renderer._DDA_mat.set_shader_parameter("voxel_count_x", new_dimensions.x)
			cortical_viz._dda_renderer._DDA_mat.set_shader_parameter("voxel_count_y", new_dimensions.y)
			cortical_viz._dda_renderer._DDA_mat.set_shader_parameter("voxel_count_z", new_dimensions.z)
			var max_dim_size: int = max(new_dimensions.x, new_dimensions.y, new_dimensions.z)
			var calculated_depth: int = ceili(log(float(max_dim_size)) / log(2.0))
			calculated_depth = maxi(calculated_depth, 1)
			cortical_viz._dda_renderer._DDA_mat.set_shader_parameter("shared_SVO_depth", calculated_depth)
			print("      🎨 Updated DDA shader parameters")
		
		# Update outline material scaling
		if cortical_viz._dda_renderer._outline_mat != null:
			cortical_viz._dda_renderer._outline_mat.set_shader_parameter("thickness_scaling", Vector3(1.0, 1.0, 1.0) / Vector3(new_dimensions))
			print("      🔍 Updated DDA outline scaling")
	
	# Update DirectPoints renderer dimensions (but preserve positioning)  
	if cortical_viz._directpoints_renderer != null:
		# Update scale but NOT position
		cortical_viz._directpoints_renderer._dimensions = new_dimensions
		if cortical_viz._directpoints_renderer._static_body != null:
			cortical_viz._directpoints_renderer._static_body.scale = new_dimensions
			# print("      📏 Updated DirectPoints renderer scale: %s" % new_dimensions)  # Suppressed - too frequent
		
		# Update collision shape size
		var collision_shape = cortical_viz._directpoints_renderer._static_body.get_child(0) as CollisionShape3D
		if collision_shape and collision_shape.shape is BoxShape3D:
			if cortical_viz._directpoints_renderer._should_use_png_icon_by_id(cortical_viz.cortical_area.cortical_ID):
				(collision_shape.shape as BoxShape3D).size = Vector3(3.0, 3.0, 1.0)  # PNG icon collision
			else:
				(collision_shape.shape as BoxShape3D).size = Vector3.ONE  # Will be scaled by static_body
			# print("      🔲 Updated DirectPoints collision shape")  # Suppressed - too frequent
		
		# Update outline mesh scale
		if cortical_viz._directpoints_renderer._outline_mesh_instance != null:
			cortical_viz._directpoints_renderer._outline_mesh_instance.scale = new_dimensions
			# print("      🔍 Updated DirectPoints outline scale")  # Suppressed - too frequent
		
		# Update outline material scaling
		if cortical_viz._directpoints_renderer._outline_mat != null:
			cortical_viz._directpoints_renderer._outline_mat.set_shader_parameter("thickness_scaling", Vector3(1.0, 1.0, 1.0) / Vector3(new_dimensions))
			# print("      🎨 Updated DirectPoints outline material")  # Suppressed - too frequent
	
	print("    ✅ Brain region dimension update completed (positioning preserved)")
	
	# Recalculate plate sizes since cortical area dimensions changed
	print("    🔄 Recalculating plate sizes after dimension change...")
	_adjust_frame_size(_get_input_cortical_areas().size(), _get_output_cortical_areas().size())

## Creates the 3D plate structure underneath I/O cortical areas
func _create_3d_plate() -> void:
	# Get input/output areas for sizing
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	
	# FEAGI FRONT-LEFT CORNER positioning - no extra offsets
	# Plates positioned directly at brain region coordinates (front-left corner)
	
	# Calculate maximum depth for reference (not used for positioning)
	var max_input_depth = 0.0
	for area in input_areas:
		max_input_depth = max(max_input_depth, area.dimensions_3D.z)
	var max_output_depth = 0.0
	for area in output_areas:
		max_output_depth = max(max_output_depth, area.dimensions_3D.z)
	
	# Calculate sizes for each plate independently - ALWAYS CREATE BOTH PLATES
	var input_plate_size = _calculate_plate_size_for_areas(input_areas, "INPUT")
	var output_plate_size = _calculate_plate_size_for_areas(output_areas, "OUTPUT")
	
	var plate_spacing = 1.0  # Gap between input and output plates
	
	# Work directly with front-edge positioning (no center calculations)
	# Godot requires center positioning, so we'll apply the offset when setting position
	
	print("  📐 Input plate size: %s (for %d areas)" % [input_plate_size, input_areas.size()])  
	print("  📐 Output plate size: %s (for %d areas)" % [output_plate_size, output_areas.size()])
	print("  📍 Brain region coordinates: %s" % _representing_region.coordinates_3D)
	
	print("  🎯 === FEAGI FRONT-LEFT CORNER POSITIONING ===")
	print("  🎯 Input plate: Front-left corner at brain region coordinates")
	print("  🎯 Output plate: Front-left corner at (region.x + input_width + gap, region.y, region.z)")
	print("  🎯 Input plate depth: %.1f units" % input_plate_size.z)
	print("  🎯 Output plate depth: %.1f units" % output_plate_size.z)
	print("  📦 All plates extend from front-left corner toward higher x,y,z values")
	
	# Create the main frame container
	_frame_container = Node3D.new()
	_frame_container.name = "RegionAssembly"
	add_child(_frame_container)
	
	# INPUT PLATE: Front-left corner at brain region coordinates (0,0,0 relative)
	var input_color = Color(0.0, 0.4, 0.0) if input_areas.size() > 0 else Color(1.0, 1.0, 0.0)  # Green or Yellow placeholder
	var input_plate = _create_single_plate(input_plate_size, "InputPlate", input_color)
	# FRONT-LEFT CORNER positioning - Godot centers meshes, so adjust by half-size
	input_plate.position.x = input_plate_size.x / 2.0  # Half-width to align front-left corner at origin
	input_plate.position.y = PLATE_HEIGHT / 2.0  # Half-height to align bottom at origin
	input_plate.position.z = input_plate_size.z / 2.0  # Half-depth to align front edge at origin
	_frame_container.add_child(input_plate)
	print("  🟢 InputPlate: Created %s plate (size: %.1f x %.1f x %.1f)" % ["green" if input_areas.size() > 0 else "yellow placeholder", input_plate_size.x, input_plate_size.y, input_plate_size.z])
	print("      📍 POSITIONED: Front-left corner at brain region coordinates (0,0,0 relative)")

	# OUTPUT PLATE: Positioned at input_width + gap from brain region front-left corner
	var output_color = Color(0.4, 0.0, 0.0) if output_areas.size() > 0 else Color(1.0, 1.0, 0.0)  # Red or Yellow placeholder
	var output_plate = _create_single_plate(output_plate_size, "OutputPlate", output_color)
	# FRONT-LEFT CORNER positioning - Output plate starts at input_width + gap
	var output_front_left_x = input_plate_size.x + PLATE_GAP
	output_plate.position.x = output_front_left_x + output_plate_size.x / 2.0  # Godot center adjustment
	output_plate.position.y = PLATE_HEIGHT / 2.0  # Same Y as input plate (Godot center)
	output_plate.position.z = output_plate_size.z / 2.0  # Half-depth to align front edge at same Z as input
	_frame_container.add_child(output_plate)
	print("  🔴 OutputPlate: Created %s plate (size: %.1f x %.1f x %.1f)" % ["red" if output_areas.size() > 0 else "yellow placeholder", output_plate_size.x, output_plate_size.y, output_plate_size.z])
	print("      📍 POSITIONED: Front-left corner at input_width + gap from region")
	
	# Create region name label below the plates
	_region_name_label = Label3D.new()
	_region_name_label.name = "RegionNameLabel"
	_region_name_label.text = _representing_region.friendly_name
	_region_name_label.font_size = 192  # Same as cortical area labels
	# Position label at center of both plates combined: Y-3 for below, Z-2 for closer to viewer
	var total_width = input_plate_size.x + PLATE_GAP + output_plate_size.x
	var center_x = total_width / 2.0  # Center between both plates
	_region_name_label.position = Vector3(center_x, -3.0, input_plate_size.x)  # Centered horizontally
	
	_region_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
	_region_name_label.outline_render_priority = 1
	_region_name_label.outline_size = 2
	_region_name_label.modulate = Color.WHITE
	# Center the label horizontally
	_region_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	_frame_container.add_child(_region_name_label)
	
	# DEBUG: Log positions AFTER adding to scene tree for accurate global_position
	print("🔍 DEBUG LABEL POSITIONING (AFTER ADDING TO TREE):")
	print("    🧠 Brain region FEAGI coordinates: %s" % _representing_region.coordinates_3D)
	print("    🧠 Brain region global_position: %s" % global_position)
	print("    🏷️ Label local position: %s" % _region_name_label.position)
	print("    🏷️ Label global_position: %s" % _region_name_label.global_position)
	print("  🏷️ RegionLabel: Created name label '%s' at Y=-3.0 with font size 192" % _representing_region.friendly_name)
	
	# Add collision bodies for click detection (as direct children for proper detection)
	_add_collision_bodies_for_clicking(input_plate_size, output_plate_size, PLATE_GAP)
	
	print("  🏗️ RegionAssembly: Created dual-plate design for region '%s'" % _representing_region.friendly_name)
	
	# DEBUG: Call manual label debug check after plate creation
	debug_label_positions()
	

## Creates a single plate mesh for inputs or outputs
func _create_single_plate(plate_size: Vector3, plate_name: String, plate_color: Color) -> MeshInstance3D:
	# Create plate mesh instance
	var plate_mesh_instance = MeshInstance3D.new()
	plate_mesh_instance.name = plate_name
	
	# Create box mesh with 1 unit thickness for better visibility
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(plate_size.x, 1.0, plate_size.z)  # 1 unit thickness in Y
	plate_mesh_instance.mesh = box_mesh
	
	# Create semi-transparent material
	var plate_material = StandardMaterial3D.new()
	plate_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate_material.albedo_color = Color(plate_color.r, plate_color.g, plate_color.b, 0.4)  # Semi-transparent
	plate_material.flags_unshaded = true
	plate_material.flags_transparent = true
	plate_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plate_material.no_depth_test = false
	plate_material.flags_do_not_receive_shadows = true
	plate_material.flags_disable_ambient_light = true
	plate_mesh_instance.material_override = plate_material
	
	# Note: StaticBody3D will be added separately as direct child of BrainRegion3D for proper click detection
	
	return plate_mesh_instance


## Adds collision bodies for clicking detection (plates and label)
func _add_collision_bodies_for_clicking(input_plate_size: Vector3, output_plate_size: Vector3, plate_gap: float) -> void:
	# Create collision body for INPUT PLATE - Front-left corner positioning
	var input_collision = StaticBody3D.new()
	input_collision.name = "InputPlateClickArea"
	input_collision.position.x = input_plate_size.x / 2.0  # Same as plate center position
	input_collision.position.y = PLATE_HEIGHT / 2.0  # Same as plate center position
	input_collision.position.z = input_plate_size.z / 2.0  # Same as plate center position
	
	var input_collision_shape = CollisionShape3D.new()
	input_collision_shape.name = "CollisionShape"
	var input_box_shape = BoxShape3D.new()
	input_box_shape.size = Vector3(input_plate_size.x, 1.0, input_plate_size.z)
	input_collision_shape.shape = input_box_shape
	input_collision.add_child(input_collision_shape)
	add_child(input_collision)  # Direct child of BrainRegion3D
	
	# Create collision body for OUTPUT PLATE - Front-left corner positioning
	var output_collision = StaticBody3D.new()
	output_collision.name = "OutputPlateClickArea"
	var output_front_left_x = input_plate_size.x + plate_gap
	output_collision.position.x = output_front_left_x + output_plate_size.x / 2.0  # Same as plate position
	output_collision.position.y = PLATE_HEIGHT / 2.0  # Same as plate position
	output_collision.position.z = output_plate_size.z / 2.0  # Same as plate position
	
	var output_collision_shape = CollisionShape3D.new()
	output_collision_shape.name = "CollisionShape"
	var output_box_shape = BoxShape3D.new()
	output_box_shape.size = Vector3(output_plate_size.x, 1.0, output_plate_size.z)
	output_collision_shape.shape = output_box_shape
	output_collision.add_child(output_collision_shape)
	add_child(output_collision)  # Direct child of BrainRegion3D
	
	# Create collision body for REGION LABEL
	var label_collision = StaticBody3D.new()
	label_collision.name = "RegionLabelClickArea"
	# Position collision same as label (centered between both plates)  
	var collision_total_width = input_plate_size.x + PLATE_GAP + output_plate_size.x
	var collision_center_x = collision_total_width / 2.0
	label_collision.position = Vector3(collision_center_x, -3.0, 2.0)  # Centered horizontally, 2 units closer to viewer
	
	var label_collision_shape = CollisionShape3D.new()
	label_collision_shape.name = "CollisionShape"
	var label_box_shape = BoxShape3D.new()
	label_box_shape.size = Vector3(8.0, 2.0, 1.0)  # Reasonable clickable area around text
	label_collision_shape.shape = label_box_shape
	label_collision.add_child(label_collision_shape)
	add_child(label_collision)  # Direct child of BrainRegion3D
	
	# DEBUG: Log collision position AFTER adding to scene tree
	print("    🎯 Collision local position: %s" % label_collision.position)
	print("    🎯 Collision global_position: %s" % label_collision.global_position)
	
	print("    🎯 Added collision detection: InputPlate (%.1f x 1.0 x %.1f), OutputPlate (%.1f x 1.0 x %.1f), Label (8.0 x 2.0 x 1.0)" % 
		[input_plate_size.x, input_plate_size.z, output_plate_size.x, output_plate_size.z])

## Creates a connecting bridge between input and output plates  
func _create_connecting_bridge(input_size: Vector3, output_size: Vector3, spacing: float) -> void:
	var bridge = MeshInstance3D.new()
	bridge.name = "ConnectingBridge"
	
	# Create a thin bridge mesh
	var bridge_mesh = BoxMesh.new()
	bridge_mesh.size = Vector3(spacing, 0.2, 1.0)  # Thin bridge
	bridge.mesh = bridge_mesh
	
	# Bridge material (darker, more subtle)
	var bridge_material = StandardMaterial3D.new()
	bridge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bridge_material.albedo_color = Color(0.3, 0.3, 0.3, 0.6)  # Dark gray, semi-transparent
	bridge_material.flags_unshaded = true
	bridge_material.flags_transparent = true
	bridge.material_override = bridge_material
	
	# Position bridge between plates
	bridge.position.x = 0.0  # Centered between plates
	bridge.position.y = -1.0  # Same level as plates
	bridge.position.z = 0.0
	
	_frame_container.add_child(bridge)
	print("  🌉 ConnectingBridge: Created bridge between input and output plates")

## Calculates plate size for specific areas using new precise specifications
func _calculate_plate_size_for_areas(areas: Array[AbstractCorticalArea], plate_type: String) -> Vector3:
	print("  🔧 Calculating %s plate size for %d areas" % [plate_type, areas.size()])
	
	# If no areas, create yellow placeholder
	if areas.size() == 0:
		print("    ⚠️  No %s areas found, using %.1fx%.1fx%.1f yellow placeholder" % [plate_type, PLACEHOLDER_PLATE_SIZE.x, PLACEHOLDER_PLATE_SIZE.y, PLACEHOLDER_PLATE_SIZE.z])
		return PLACEHOLDER_PLATE_SIZE
	
	# Calculate width: sum of all area widths + buffers + margins
	var total_width = 0.0
	var max_depth = 0.0
	
	for area in areas:
		total_width += area.dimensions_3D.x  # Sum all widths
		max_depth = max(max_depth, area.dimensions_3D.z)  # Find max depth
		print("    📦 Area %s: width=%.1f, depth=%.1f" % [area.cortical_ID, area.dimensions_3D.x, area.dimensions_3D.z])
	
	# Width calculation: sum_of_widths + (count-1)*BUFFER + SIDE_MARGINS
	var plate_width = total_width + (areas.size() - 1) * AREA_BUFFER_DISTANCE + (PLATE_SIDE_MARGIN * 2.0)
	
	# Depth calculation: max_depth + FRONT_BACK_MARGINS  
	var plate_depth = max_depth + (PLATE_FRONT_BACK_MARGIN * 2.0)
	
	# Height is always constant
	var plate_height = PLATE_HEIGHT
	
	print("    📐 %s plate calculation:" % plate_type)
	print("      • Total area widths: %.1f" % total_width)
	print("      • Buffer between areas: %d areas × %.1f units = %.1f" % [(areas.size() - 1), AREA_BUFFER_DISTANCE, (areas.size() - 1) * AREA_BUFFER_DISTANCE])
	print("      • Side margins: %.1f units (%.1f each side)" % [PLATE_SIDE_MARGIN * 2.0, PLATE_SIDE_MARGIN])
	print("      • Final width: %.1f + %.1f + %.1f = %.1f" % [total_width, (areas.size() - 1) * AREA_BUFFER_DISTANCE, PLATE_SIDE_MARGIN * 2.0, plate_width])
	print("      • Max depth: %.1f + %.1f margin = %.1f" % [max_depth, PLATE_FRONT_BACK_MARGIN * 2.0, plate_depth])
	print("      • Height: %.1f (constant)" % plate_height)
	
	return Vector3(plate_width, plate_height, plate_depth)

## Creates a custom wireframe cube mesh using line topology (DEPRECATED - replaced by plate)
func _create_wireframe_cube_mesh(size: Vector3) -> ArrayMesh:
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var half = size / 2.0
	
	# Define 8 vertices of the cube
	var vertices = PackedVector3Array()
	vertices.append(Vector3(-half.x, -half.y, -half.z))  # 0: bottom-back-left
	vertices.append(Vector3(half.x, -half.y, -half.z))   # 1: bottom-back-right
	vertices.append(Vector3(half.x, -half.y, half.z))    # 2: bottom-front-right
	vertices.append(Vector3(-half.x, -half.y, half.z))   # 3: bottom-front-left
	vertices.append(Vector3(-half.x, half.y, -half.z))   # 4: top-back-left
	vertices.append(Vector3(half.x, half.y, -half.z))    # 5: top-back-right
	vertices.append(Vector3(half.x, half.y, half.z))     # 6: top-front-right
	vertices.append(Vector3(-half.x, half.y, half.z))    # 7: top-front-left
	
	# Define 12 edges (lines) connecting the vertices
	var indices = PackedInt32Array()
	# Bottom face edges
	indices.append_array([0, 1, 1, 2, 2, 3, 3, 0])
	# Top face edges  
	indices.append_array([4, 5, 5, 6, 6, 7, 7, 4])
	# Vertical edges connecting bottom to top
	indices.append_array([0, 4, 1, 5, 2, 6, 3, 7])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	# Create the mesh surface with LINE primitive
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	
	return array_mesh

## Creates containers for input and output areas
func _create_containers() -> void:
	_input_areas_container = Node3D.new()
	_input_areas_container.name = "InputAreas"
	add_child(_input_areas_container)
	
	_output_areas_container = Node3D.new()
	_output_areas_container.name = "OutputAreas"
	add_child(_output_areas_container)
	
	# Position containers (input on left, output on right)
	_input_areas_container.position = Vector3(-INPUT_OUTPUT_SPACING, 0, 0)
	_output_areas_container.position = Vector3(INPUT_OUTPUT_SPACING, 0, 0)

## Populates the plate with cortical areas based on I/O classification
func _populate_cortical_areas() -> void:
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	
	print("🧠 BrainRegion3D: Populating region '%s' plate with I/O areas:" % _representing_region.friendly_name)
	print("  📥 Input areas to show on plate: %d" % input_areas.size())
	for area in input_areas:
		print("    🔵 %s (%s) - will be positioned on LEFT side of plate" % [area.cortical_ID, area.type_as_string])
	print("  📤 Output areas to show on plate: %d" % output_areas.size()) 
	for area in output_areas:
		print("    🔴 %s (%s) - will be positioned on RIGHT side of plate" % [area.cortical_ID, area.type_as_string])
	
	if input_areas.size() == 0 and output_areas.size() == 0:
		print("  ⚠️  No I/O areas found! Plate will have no overlying cortical areas.")
		print("  🔍 Debug info:")
		print("    - Region has %d input_open_chain_links" % _representing_region.input_open_chain_links.size())
		print("    - Region has %d output_open_chain_links" % _representing_region.output_open_chain_links.size())
		print("    - Region contains %d cortical areas directly" % _representing_region.contained_cortical_areas.size())
	
	# Get reference to the 3D scene that manages all cortical area visualizations
	print("  🔍 Searching for UI_BrainMonitor_3DScene parent...")
	print("    - Current parent: %s" % get_parent())
	print("    - Grandparent: %s" % (get_parent().get_parent() if get_parent() else "none"))
	
	var brain_monitor_3d: UI_BrainMonitor_3DScene = get_parent().get_parent() as UI_BrainMonitor_3DScene
	if not brain_monitor_3d:
		# Try different parent paths
		var current_node = self
		var search_depth = 0
		while current_node and search_depth < 5:
			current_node = current_node.get_parent()
			search_depth += 1
			print("    - Checking parent level %d: %s (type: %s)" % [search_depth, current_node, current_node.get_class() if current_node else "none"])
			if current_node is UI_BrainMonitor_3DScene:
				brain_monitor_3d = current_node as UI_BrainMonitor_3DScene
				print("    ✅ Found UI_BrainMonitor_3DScene at level %d!" % search_depth)
				break
		
		if not brain_monitor_3d:
			print("  ❌ Could not find UI_BrainMonitor_3DScene parent anywhere!")
			return
	
	# Move input area visualizations from main scene to our plate
	for i in input_areas.size():
		var area = input_areas[i]
		var existing_viz = brain_monitor_3d.get_cortical_area_visualization(area.cortical_ID)
		if existing_viz:
			print("    🔄 Moving input area %s from main scene to plate left side" % area.cortical_ID)
			var old_parent = existing_viz.get_parent()
			print("      🔍 OLD parent: %s" % old_parent.name if old_parent else "none")
			
			# CRITICAL: Disconnect coordinate update signals to prevent fighting parent-child movement
			print("      🔌 Disconnecting coordinate update signals to prevent position override...")
			if area.coordinates_3D_updated.is_connected(existing_viz.set_new_position):
				area.coordinates_3D_updated.disconnect(existing_viz.set_new_position)
				print("      ✂️  Disconnected main visualization coordinate updates")
			
			# Also disconnect renderer coordinate updates
			if existing_viz._dda_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate):
				area.coordinates_3D_updated.disconnect(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate)
				print("      ✂️  Disconnected DDA renderer coordinate updates")
				
			if existing_viz._directpoints_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate):
				area.coordinates_3D_updated.disconnect(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate)
				print("      ✂️  Disconnected DirectPoints renderer coordinate updates")
			
			# CRITICAL: Also disconnect dimension update signals to prevent position conflicts
			if existing_viz._dda_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._dda_renderer.update_dimensions):
				area.dimensions_3D_updated.disconnect(existing_viz._dda_renderer.update_dimensions)
				print("      ✂️  Disconnected DDA renderer dimension updates")
				
			if existing_viz._directpoints_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._directpoints_renderer.update_dimensions):
				area.dimensions_3D_updated.disconnect(existing_viz._directpoints_renderer.update_dimensions)
				print("      ✂️  Disconnected DirectPoints renderer dimension updates")
			
			# Connect to our custom dimension update handler that preserves brain region positioning
			area.dimensions_3D_updated.connect(_on_io_cortical_area_dimensions_changed.bind(area.cortical_ID))
			print("      🔌 Connected to brain region dimension update handler for %s" % area.cortical_ID)
			
			existing_viz.get_parent().remove_child(existing_viz)
			_input_areas_container.add_child(existing_viz)
			print("      🔍 NEW parent: %s" % existing_viz.get_parent().name)
			print("      🔍 NEW parent hierarchy: %s -> %s -> %s" % [existing_viz.get_parent().get_parent().name, existing_viz.get_parent().name, existing_viz.name])
			# _scale_cortical_area_visualization(existing_viz, 0.8)  # Removed - preserve original cortical area dimensions
			_position_cortical_area_on_plate(existing_viz, i, input_areas.size(), true)  # true = is_input
			_cortical_area_visualizations[area.cortical_ID] = existing_viz
		else:
			print("    ❌ Could not find existing visualization for input area %s" % area.cortical_ID)
	
	# Move output area visualizations from main scene to our plate
	for i in output_areas.size():
		var area = output_areas[i]
		var existing_viz = brain_monitor_3d.get_cortical_area_visualization(area.cortical_ID)
		if existing_viz:
			print("    🔄 Moving output area %s from main scene to plate right side" % area.cortical_ID)
			var old_parent = existing_viz.get_parent()
			print("      🔍 OLD parent: %s" % old_parent.name if old_parent else "none")
			
			# CRITICAL: Disconnect coordinate update signals to prevent fighting parent-child movement
			print("      🔌 Disconnecting coordinate update signals to prevent position override...")
			if area.coordinates_3D_updated.is_connected(existing_viz.set_new_position):
				area.coordinates_3D_updated.disconnect(existing_viz.set_new_position)
				print("      ✂️  Disconnected main visualization coordinate updates")
			
			# Also disconnect renderer coordinate updates
			if existing_viz._dda_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate):
				area.coordinates_3D_updated.disconnect(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate)
				print("      ✂️  Disconnected DDA renderer coordinate updates")
				
			if existing_viz._directpoints_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate):
				area.coordinates_3D_updated.disconnect(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate)
				print("      ✂️  Disconnected DirectPoints renderer coordinate updates")
			
			# CRITICAL: Also disconnect dimension update signals to prevent position conflicts
			if existing_viz._dda_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._dda_renderer.update_dimensions):
				area.dimensions_3D_updated.disconnect(existing_viz._dda_renderer.update_dimensions)
				print("      ✂️  Disconnected DDA renderer dimension updates")
				
			if existing_viz._directpoints_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._directpoints_renderer.update_dimensions):
				area.dimensions_3D_updated.disconnect(existing_viz._directpoints_renderer.update_dimensions)
				print("      ✂️  Disconnected DirectPoints renderer dimension updates")
			
			existing_viz.get_parent().remove_child(existing_viz)
			_output_areas_container.add_child(existing_viz)
			print("      🔍 NEW parent: %s" % existing_viz.get_parent().name)
			print("      🔍 NEW parent hierarchy: %s -> %s -> %s" % [existing_viz.get_parent().get_parent().name, existing_viz.get_parent().name, existing_viz.name])
			# _scale_cortical_area_visualization(existing_viz, 0.8)  # Removed - preserve original cortical area dimensions
			_position_cortical_area_on_plate(existing_viz, i, output_areas.size(), false)  # false = is_output
			_cortical_area_visualizations[area.cortical_ID] = existing_viz
		else:
			print("    ❌ Could not find existing visualization for output area %s" % area.cortical_ID)
	
	# Adjust frame size based on content
	_adjust_frame_size(input_areas.size(), output_areas.size())
	
	# Final verification of parenting
	print("🔍 FINAL PARENTING CHECK:")
	print("  📥 Input container children: %d" % _input_areas_container.get_child_count())
	print("  📤 Output container children: %d" % _output_areas_container.get_child_count())
	print("  🏗️ Brain region total children: %d" % get_child_count())
	print("  ✅ Cortical areas should now move WITH brain region (signals disconnected)")

## Scales a cortical area visualization by scaling the 3D bodies within the renderers
func _scale_cortical_area_visualization(cortical_viz: UI_BrainMonitor_CorticalArea, scale_factor: float) -> void:
	# Scale the DDA renderer's static body if it exists
	if cortical_viz._dda_renderer != null and cortical_viz._dda_renderer._static_body != null:
		cortical_viz._dda_renderer._static_body.scale = Vector3.ONE * scale_factor
		# Also scale the label if it exists
		if cortical_viz._dda_renderer._friendly_name_label != null:
			cortical_viz._dda_renderer._friendly_name_label.scale = Vector3.ONE * scale_factor
	
	# Scale the DirectPoints renderer's static body if it exists  
	if cortical_viz._directpoints_renderer != null and cortical_viz._directpoints_renderer._static_body != null:
		cortical_viz._directpoints_renderer._static_body.scale = Vector3.ONE * scale_factor
		# Also scale the label if it exists
		if cortical_viz._directpoints_renderer._friendly_name_label != null:
			cortical_viz._directpoints_renderer._friendly_name_label.scale = Vector3.ONE * scale_factor
	
	# print("    📏 Scaled cortical area %s renderer bodies to %s" % [cortical_viz.cortical_area.cortical_ID, scale_factor])  # Suppressed to reduce log overflow

## Positions a cortical area on the plate using generated absolute coordinates
func _position_cortical_area_on_plate(cortical_viz: UI_BrainMonitor_CorticalArea, index: int, total_count: int, is_input: bool) -> void:
	# Use generated coordinates instead of hardcoded positioning
	var cortical_id = cortical_viz.cortical_area.cortical_ID
	var new_position = Vector3(0, 0, 0)  # fallback
	var found_generated_coords = false
	
	# Look for cortical area in generated coordinates
	
	# Look for this cortical area in the generated coordinates
	var areas_to_search = _generated_io_coordinates.inputs if is_input else _generated_io_coordinates.outputs
	for area_data in areas_to_search:
		if area_data.area_id == cortical_id:
			# Convert generated absolute FEAGI coordinates to relative position within brain region
			var absolute_feagi_coords = Vector3(area_data.new_coordinates)
			var brain_region_coords = Vector3(_representing_region.coordinates_3D)
			var relative_position = absolute_feagi_coords - brain_region_coords
			new_position = Vector3(relative_position.x, relative_position.y, relative_position.z)  # Use generated Y coordinate
			found_generated_coords = true
			print("    📍 Using generated coords for %s: absolute %s -> relative %s" % [cortical_id, absolute_feagi_coords, new_position])
			break
	
	if not found_generated_coords:
		push_error("BrainRegion3D: No generated coordinates found for cortical area %s - this should not happen!" % cortical_id)
		return
	
	var side_label = "LEFT (input)" if is_input else "RIGHT (output)"
	
	print("    🎯 POSITIONING cortical area %s with position %s (relative to brain region)" % [cortical_id, new_position])
	
	# Calculate position relative to the appropriate container (InputAreas or OutputAreas)
	var container = _input_areas_container if is_input else _output_areas_container
	
	# Convert brain region FEAGI coordinates to Godot world position (same logic as _update_position)
	var brain_region_coords = _representing_region.coordinates_3D
	var brain_region_world_pos = Vector3(brain_region_coords.x, brain_region_coords.y, -brain_region_coords.z)
	
	# Calculate desired world position: brain_region_world + relative_offset
	var desired_world_pos = brain_region_world_pos + new_position
	
	# Container position relative to brain region (from _create_containers)
	var container_offset = Vector3(-INPUT_OUTPUT_SPACING, 0, 0) if is_input else Vector3(INPUT_OUTPUT_SPACING, 0, 0)
	var container_world_pos = brain_region_world_pos + container_offset
	
	# Calculate position relative to container: desired_world - container_world  
	var position_relative_to_container = desired_world_pos - container_world_pos
	
	print("      🔍 Brain region world: %s, Container world: %s" % [brain_region_world_pos, container_world_pos])
	print("      🎯 Desired world position: %s" % desired_world_pos)
	print("      📐 Position relative to container: %s" % position_relative_to_container)
	
	# CRITICAL FIX: Use GLOBAL positioning since the renderer static bodies are not proper children of containers
	# The UI_BrainMonitor_CorticalArea is a Node (not Node3D), so it doesn't participate in 3D positioning
	# We need to set absolute world positions directly
	
	# print("      🔧 Setting GLOBAL renderer position to %s" % desired_world_pos)  # Suppressed - too frequent
	
	# Position the DDA renderer's static body if it exists
	if cortical_viz._dda_renderer != null and cortical_viz._dda_renderer._static_body != null:
		cortical_viz._dda_renderer._static_body.global_position = desired_world_pos
		# print("        ✅ DDA renderer global_position set to %s" % cortical_viz._dda_renderer._static_body.global_position)  # Suppressed - too frequent
		# Also position the label if it exists
		if cortical_viz._dda_renderer._friendly_name_label != null:
			cortical_viz._dda_renderer._friendly_name_label.global_position = desired_world_pos + Vector3(0, 1.0, 0)  # Label above cortical area
	
	# Position the DirectPoints renderer's static body if it exists  
	if cortical_viz._directpoints_renderer != null and cortical_viz._directpoints_renderer._static_body != null:
		cortical_viz._directpoints_renderer._static_body.global_position = desired_world_pos
		# print("        ✅ DirectPoints renderer global_position set to %s" % cortical_viz._directpoints_renderer._static_body.global_position)  # Suppressed - too frequent
		# Also position the label if it exists
		if cortical_viz._directpoints_renderer._friendly_name_label != null:
			cortical_viz._directpoints_renderer._friendly_name_label.global_position = desired_world_pos + Vector3(0, 1.0, 0)  # Label above cortical area
	
	print("    ✅ Cortical area %s positioned on plate" % cortical_id)
	
	# print("    📍 Positioned %s on plate %s at Z-offset %.1f" % [cortical_viz.cortical_area.cortical_ID, side_label, z_offset])  # Suppressed to reduce log overflow

## Gets input cortical areas based on connection chain links or direct areas
func _get_input_cortical_areas() -> Array[AbstractCorticalArea]:
	var input_areas: Array[AbstractCorticalArea] = []
	
	print("🔍 Analyzing input areas for region '%s':" % _representing_region.friendly_name)
	print("  📋 input_open_chain_links count: %d" % _representing_region.input_open_chain_links.size())
	
	# Method 1: Check input_open_chain_links for areas that receive input
	for i in range(_representing_region.input_open_chain_links.size()):
		var link: ConnectionChainLink = _representing_region.input_open_chain_links[i]
		print("    🔗 Input link %d: source=%s, destination=%s" % [i, 
			link.source.genome_ID if link.source else "null",
			link.destination.genome_ID if link.destination else "null"])
		
		if link.destination and link.destination is AbstractCorticalArea:
			var area = link.destination as AbstractCorticalArea
			if area not in input_areas:
				input_areas.append(area)
				print("      ✅ Added input area: %s (%s)" % [area.cortical_ID, area.type_as_string])
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays) - CRITICAL FIX!
	print("  📋 partial_mappings count: %d" % _representing_region.partial_mappings.size())
	for partial_mapping in _representing_region.partial_mappings:
		if partial_mapping.is_region_input:
			var area = partial_mapping.internal_target_cortical_area
			if area not in input_areas:
				input_areas.append(area)
				print("      ✅ Added input area via partial mapping: %s (%s)" % [area.cortical_ID, area.type_as_string])
	
	# Method 3: If no chain links, fall back to checking IPU types and making educated guesses
	if _representing_region.input_open_chain_links.size() == 0:
		print("  ⚠️  No input chain links found. Using fallback detection methods...")
		
		# Check for IPU type areas directly contained in this brain region
		print("  🔍 Checking directly contained cortical areas for IPU types...")
		for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
			print("    📦 Contained area: %s (type: %s)" % [area.cortical_ID, area.type_as_string])
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU and area not in input_areas:
				input_areas.append(area)
				print("      ✅ Added IPU input area: %s" % area.cortical_ID)
		
		# TEMPORARY: Aggressive fallback for debugging (will restore conservative logic after)
		if input_areas.size() == 0 and _representing_region.contained_cortical_areas.size() == 2:
			print("  💡 TEMPORARY: Using aggressive heuristics to debug input detection...")
			for area in _representing_region.contained_cortical_areas:
				var area_id = area.cortical_ID.to_lower()
				# Look for common input patterns in names (c__lef should be input per FEAGI pattern)
				if "lef" in area_id or "left" in area_id or "input" in area_id or "in" in area_id or "inp" in area_id:
					input_areas.append(area)
					print("      🎯 AGGRESSIVE: Selected as input (name heuristic): %s" % area.cortical_ID)
					break
			
			# NOTE: Since FEAGI says "inputs": [], we expect 0 input areas
			# This aggressive test is just to see if detection logic works
	
	print("🔍 Total input areas found for '%s': %d" % [_representing_region.friendly_name, input_areas.size()])
	return input_areas

## Gets output cortical areas based on connection chain links or direct areas
func _get_output_cortical_areas() -> Array[AbstractCorticalArea]:
	var output_areas: Array[AbstractCorticalArea] = []
	
	print("🔍 Analyzing output areas for region '%s':" % _representing_region.friendly_name)
	print("  📋 output_open_chain_links count: %d" % _representing_region.output_open_chain_links.size())
	print("  📋 contained_cortical_areas count: %d" % _representing_region.contained_cortical_areas.size())
	for area in _representing_region.contained_cortical_areas:
		print("    🔍 Contained area: %s (type: %s)" % [area.cortical_ID, area.type_as_string])
	
	# Method 1: Check output_open_chain_links for areas that provide output
	for i in range(_representing_region.output_open_chain_links.size()):
		var link: ConnectionChainLink = _representing_region.output_open_chain_links[i]
		print("    🔗 Output link %d: source=%s, destination=%s" % [i,
			link.source.genome_ID if link.source else "null", 
			link.destination.genome_ID if link.destination else "null"])
		
		if link.source and link.source is AbstractCorticalArea:
			var area = link.source as AbstractCorticalArea
			if area not in output_areas:
				output_areas.append(area)
				print("      ✅ Added output area: %s (%s)" % [area.cortical_ID, area.type_as_string])
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays) - CRITICAL FIX!
	print("  📋 partial_mappings count: %d" % _representing_region.partial_mappings.size())
	for partial_mapping in _representing_region.partial_mappings:
		if not partial_mapping.is_region_input:  # Output mapping
			var area = partial_mapping.internal_target_cortical_area
			if area not in output_areas:
				output_areas.append(area)
				print("      ✅ Added output area via partial mapping: %s (%s)" % [area.cortical_ID, area.type_as_string])
	
	# Method 3: If no chain links, fall back to checking OPU types and making educated guesses
	if _representing_region.output_open_chain_links.size() == 0:
		print("  ⚠️  No output chain links found. Using fallback detection methods...")
		
		# Check for OPU type areas directly contained in this brain region
		print("  🔍 Checking directly contained cortical areas for OPU types...")
		for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
			print("    📦 Contained area: %s (type: %s)" % [area.cortical_ID, area.type_as_string])
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU and area not in output_areas:
				output_areas.append(area)
				print("      ✅ Added OPU output area: %s" % area.cortical_ID)
		
		# TEMPORARY: Aggressive fallback for debugging (will restore conservative logic after)
		if output_areas.size() == 0 and _representing_region.contained_cortical_areas.size() == 2:
			print("  💡 TEMPORARY: Using aggressive heuristics to debug output detection...")
			for area in _representing_region.contained_cortical_areas:
				var area_id = area.cortical_ID.to_lower()
				# Look for common output patterns in names (c__lef should match "lef") 
				if "lef" in area_id or "left" in area_id or "output" in area_id or "out" in area_id:
					output_areas.append(area)
					print("      🎯 AGGRESSIVE: Selected as output (name heuristic): %s" % area.cortical_ID)
					break
				# Also check for "rig" in outputs (user says c__rig should be output)
				elif "rig" in area_id or "right" in area_id:
					output_areas.append(area)
					print("      🎯 AGGRESSIVE: Selected as output (name heuristic for rig): %s" % area.cortical_ID)
					break
	
	print("🔍 Total output areas found for '%s': %d" % [_representing_region.friendly_name, output_areas.size()])
	return output_areas

## Adjusts frame size based on contained cortical areas
func _adjust_frame_size(input_count: int, output_count: int) -> void:
	var max_count = max(input_count, output_count)
	var required_height = max(3.0, max_count * CORTICAL_AREA_SPACING + FRAME_PADDING.y)
	var required_width = INPUT_OUTPUT_SPACING * 2 + FRAME_PADDING.x * 2
	var required_depth = FRAME_PADDING.z * 2
	
	var new_size = Vector3(required_width, required_height, required_depth)
	
	# Update plate size (plates don't need dynamic resizing like wireframes did)
	# Plates are sized based on I/O area dimensions, not container content
	print("  📏 Frame size adjustment requested, but plates auto-size based on I/O areas")
	
	# Update collision shape (if collision exists)
	if _frame_collision != null and _frame_collision.get_child_count() > 0 and _frame_collision.get_child(0).shape is BoxShape3D:
		(_frame_collision.get_child(0).shape as BoxShape3D).size = new_size
	
	# Note: Position is already set correctly in setup() - no need to update here

## Updates the plate size (DEPRECATED - plates auto-size based on I/O areas)
func _update_wireframe_size(new_size: Vector3) -> void:
	# This method is deprecated - plates are sized automatically based on I/O cortical areas
	# Keeping method for compatibility but no longer recreating wireframe mesh
	print("  ⚠️  _update_wireframe_size() called but plates auto-size based on I/O areas")

## Updates position based on brain region coordinates (moves brain region AND all I/O cortical areas)
## IMPORTANT: This moves ONLY the visual representation - does NOT update underlying FEAGI cortical area coordinates
func _update_position(new_coordinates: Vector3i) -> void:
	# Convert FEAGI coordinates to Godot 3D space
	# Brain region coordinates represent the LOWEST corner (minimum x,y,z) of the plate
	# Z-axis needs to be flipped for proper orientation
	
	# FEAGI coordinates = front-left corner of INPUT plate
	var godot_position = Vector3(new_coordinates.x, new_coordinates.y, -new_coordinates.z)
	global_position = godot_position
	
	print("🧠 BrainRegion3D: Positioned region '%s' at FEAGI coords %s -> global_position %s" % 
		[_representing_region.friendly_name, new_coordinates, global_position])
	print("  📍 Region coordinates = front-left corner of INPUT plate")
	
	# DEBUG: Check label positions after positioning
	debug_label_positions()
	
	# Update I/O cortical area positions to maintain relative positioning
	_update_io_area_global_positions()

## Logs the current positions of all I/O cortical areas
func _log_io_area_current_positions() -> void:
	if _input_areas_container:
		print("  📥 INPUT AREA POSITIONS:")
		for child in _input_areas_container.get_children():
			var cortical_viz = child as UI_BrainMonitor_CorticalArea
			if cortical_viz:
				_log_single_cortical_area_position(cortical_viz, "INPUT")
	
	if _output_areas_container:
		print("  📤 OUTPUT AREA POSITIONS:")
		for child in _output_areas_container.get_children():
			var cortical_viz = child as UI_BrainMonitor_CorticalArea
			if cortical_viz:
				_log_single_cortical_area_position(cortical_viz, "OUTPUT")

## Logs the position details for a single cortical area
func _log_single_cortical_area_position(cortical_viz: UI_BrainMonitor_CorticalArea, type_label: String) -> void:
	var area = cortical_viz._representing_cortial_area
	var area_id = area.cortical_ID if area else "unknown"
	
	print("    🔵 %s %s:" % [type_label, area_id])
	
	# Log positions from both renderers
	if cortical_viz._dda_renderer != null and cortical_viz._dda_renderer._static_body != null:
		var local_pos = cortical_viz._dda_renderer._static_body.position
		var global_pos = cortical_viz._dda_renderer._static_body.global_position
		# print("      📍 DDA renderer - Local: %s, Global: %s" % [local_pos, global_pos])  # Suppressed - debug spam
	
	if cortical_viz._directpoints_renderer != null and cortical_viz._directpoints_renderer._static_body != null:
		var local_pos = cortical_viz._directpoints_renderer._static_body.position
		var global_pos = cortical_viz._directpoints_renderer._static_body.global_position
		# print("      📍 DirectPoints renderer - Local: %s, Global: %s" % [local_pos, global_pos])  # Suppressed - debug spam
	
	# Note: UI_BrainMonitor_CorticalArea is a Node (not Node3D), so it has no position property
	# The actual positioning is handled by its child renderers (_dda_renderer and _directpoints_renderer)

## Updates global positions of all I/O cortical areas when brain region moves
func _update_io_area_global_positions() -> void:
	print("    🔄 Recalculating I/O area positions for moved brain region...")
	
	# CRITICAL FIX: Regenerate I/O coordinates based on current brain region position
	# The old stored coordinates were based on the previous brain region position
	_generated_io_coordinates = generate_io_coordinates_for_brain_region(_representing_region)
	
	# Convert new brain region FEAGI coordinates to Godot world position
	var brain_region_coords = _representing_region.coordinates_3D
	var brain_region_world_pos = Vector3(brain_region_coords.x, brain_region_coords.y, -brain_region_coords.z)
	
	# Update each cortical area to its new position
	for cortical_id in _cortical_area_visualizations.keys():
		var cortical_viz = _cortical_area_visualizations[cortical_id]
		print("      🔍 Updating cortical area: %s" % cortical_id)
		
		# Find the NEW absolute coordinates for this cortical area
		var found_coords = false
		var desired_world_pos = Vector3.ZERO
		
		# Check inputs
		for area_data in _generated_io_coordinates.inputs:
			if area_data.area_id == cortical_id:
				var new_feagi_coords = Vector3(area_data.new_coordinates)
				new_feagi_coords.z = -new_feagi_coords.z  # Flip Z for Godot
				desired_world_pos = new_feagi_coords
				found_coords = true
				print("        ✅ Found as INPUT: %s -> world pos: %s" % [cortical_id, desired_world_pos])
				break
		
		# Check outputs if not found in inputs
		if not found_coords:
			for area_data in _generated_io_coordinates.outputs:
				if area_data.area_id == cortical_id:
					var new_feagi_coords = Vector3(area_data.new_coordinates)
					new_feagi_coords.z = -new_feagi_coords.z  # Flip Z for Godot
					desired_world_pos = new_feagi_coords
					found_coords = true
					print("        ✅ Found as OUTPUT: %s -> world pos: %s" % [cortical_id, desired_world_pos])
					break
		
		if found_coords:
			# Update DDA renderer position
			if cortical_viz._dda_renderer != null and cortical_viz._dda_renderer._static_body != null:
				cortical_viz._dda_renderer._static_body.global_position = desired_world_pos
				if cortical_viz._dda_renderer._friendly_name_label != null:
					cortical_viz._dda_renderer._friendly_name_label.global_position = desired_world_pos + Vector3(0, 1.0, 0)
			
			# Update DirectPoints renderer position  
			if cortical_viz._directpoints_renderer != null and cortical_viz._directpoints_renderer._static_body != null:
				cortical_viz._directpoints_renderer._static_body.global_position = desired_world_pos
				if cortical_viz._directpoints_renderer._friendly_name_label != null:
					cortical_viz._directpoints_renderer._friendly_name_label.global_position = desired_world_pos + Vector3(0, 1.0, 0)
		else:
			print("        ❌ No coordinates found for %s - this shouldn't happen!" % cortical_id)
	
	print("    ✅ I/O cortical area position update complete")

## Updates all I/O cortical area positions when brain region moves (maintains relative offsets) - DISABLED
func _update_io_area_positions_DISABLED() -> void:
	print("    🔄 Repositioning all I/O cortical areas to maintain relative positions...")
	
	# Go through all stored cortical area visualizations and reposition them
	for cortical_id in _cortical_area_visualizations.keys():
		var cortical_viz = _cortical_area_visualizations[cortical_id]
		
		# Find this cortical area in the generated coordinates to get its relative offset
		var found_coords = false
		var new_position = Vector3.ZERO
		
		# Check inputs
		for area_data in _generated_io_coordinates.inputs:
			if area_data.area_id == cortical_id:
				# Calculate new absolute position: current brain region position + stored relative offset
				var region_origin = Vector3(_representing_region.coordinates_3D)
				var input_offset = Vector3(1.0, 0.0, 0.0)  # Same offset as coordinate generation
				new_position = Vector3(input_offset.x, 0.0, input_offset.z)  # Y=0 for plate surface
				found_coords = true
				print("      📍 Repositioned INPUT %s to relative position %s" % [cortical_id, new_position])
				break
		
		# Check outputs if not found in inputs
		if not found_coords:
			for area_data in _generated_io_coordinates.outputs:
				if area_data.area_id == cortical_id:
					# Calculate new absolute position: current brain region position + stored relative offset  
					var region_origin = Vector3(_representing_region.coordinates_3D)
					var output_offset = Vector3(5.0, 0.0, 0.0)  # Same offset as coordinate generation
					new_position = Vector3(output_offset.x, 0.0, output_offset.z)  # Y=0 for plate surface
					found_coords = true
					print("      📍 Repositioned OUTPUT %s to relative position %s" % [cortical_id, new_position])
					break
		
		if found_coords:
			# Apply the new position to the cortical area renderers
			if cortical_viz._dda_renderer != null and cortical_viz._dda_renderer._static_body != null:
				cortical_viz._dda_renderer._static_body.position = new_position
				if cortical_viz._dda_renderer._friendly_name_label != null:
					cortical_viz._dda_renderer._friendly_name_label.position = new_position + Vector3(0, 1.0, 0)
			
			if cortical_viz._directpoints_renderer != null and cortical_viz._directpoints_renderer._static_body != null:
				cortical_viz._directpoints_renderer._static_body.position = new_position
				if cortical_viz._directpoints_renderer._friendly_name_label != null:
					cortical_viz._directpoints_renderer._friendly_name_label.position = new_position + Vector3(0, 1.0, 0)
		else:
			print("      ⚠️  Could not find relative coordinates for %s - skipping reposition" % cortical_id)
	
	print("    ✅ I/O cortical area repositioning complete")

## Updates frame label/appearance when region name changes
func _update_frame_label(new_name: StringName) -> void:
	# Update node name
	name = "BrainRegion3D_" + _representing_region.region_ID + "_" + str(new_name)
	
	# Update the region name label if it exists
	if _region_name_label:
		_region_name_label.text = str(new_name)
		print("  🏷️ Updated region label text to: '%s'" % new_name)

## Signal handlers for dynamic updates
func _on_cortical_area_added(area: AbstractCorticalArea) -> void:
	print("🧠 BrainRegion3D: Cortical area added to region, refreshing frame")
	_refresh_frame_contents()

func _on_cortical_area_removed(area: AbstractCorticalArea) -> void:
	print("🧠 BrainRegion3D: Cortical area removed from region, refreshing frame")
	if area.cortical_ID in _cortical_area_visualizations:
		_cortical_area_visualizations[area.cortical_ID].queue_free()
		_cortical_area_visualizations.erase(area.cortical_ID)
	_refresh_frame_contents()

## Refreshes the entire frame contents
func _refresh_frame_contents() -> void:
	# Clear existing visualizations
	for viz in _cortical_area_visualizations.values():
		viz.queue_free()
	_cortical_area_visualizations.clear()
	
	# Position the brain region: FEAGI coordinates = front-left corner of INPUT plate
	if _representing_region:
		var coords = _representing_region.coordinates_3D
		var godot_position = Vector3(coords.x, coords.y, -coords.z)
		global_position = godot_position
		
		# DEBUG: Log label positions during refresh
		if _region_name_label:
			print("🔍 DEBUG LABEL POSITIONING (DURING REFRESH):")
			print("    🧠 Brain region FEAGI coordinates: %s" % coords)
			print("    🧠 Brain region global_position: %s" % global_position)
			print("    🏷️ Label local position: %s" % _region_name_label.position)
			print("    🏷️ Label global_position: %s" % _region_name_label.global_position)
		print("🔧 REFRESH: Positioned brain region '%s' at FEAGI coords %s -> global_position %s" % [_representing_region.friendly_name, coords, global_position])
		print("  📍 Region coordinates = front-left corner of INPUT plate")
	
	# Repopulate
	_populate_cortical_areas()

## Handles hover/selection interaction
func set_hover_state(is_hovered: bool) -> void:
	# Note: Dual-plate design doesn't need hover color changes - plates already have distinct colors
	# Input plate: dark green, Output plate: dark blue
	
	region_hover_changed.emit(_representing_region, is_hovered)

## Handles double-click for diving into region
func handle_double_click() -> void:
	region_double_clicked.emit(_representing_region)
	print("🧠 BrainRegion3D: Double-clicked region '%s' - ready for dive-in navigation" % _representing_region.friendly_name)
