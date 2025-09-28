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
var _conflict_areas_container: Node3D
var _region_name_label: Label3D
var _cortical_area_visualizations: Dictionary[StringName, UI_BrainMonitor_CorticalArea] = {}
var _generated_io_coordinates: Dictionary = {}  # Stores the generated I/O coordinates

## Logs dimensions of all I/O cortical areas for plate sizing calculations
func _log_io_area_dimensions(brain_region: BrainRegion) -> void:
	var input_areas = _get_input_cortical_areas_for_logging(brain_region)
	var output_areas = _get_output_cortical_areas_for_logging(brain_region)
	
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
## Areas are positioned ABOVE the plates using front-left corner positioning internally, 
## but converted to CENTER coordinates for Godot renderers:
## - Front-left corners calculated with proper margins and buffers from plates  
## - CENTER coordinates passed to renderers: (front-left + X/2, front-left + Y/2, front-left - Z/2)
## - X,Y: Standard center calculation (front-left + dimension/2.0)
## - Z: Subtract dimension/2.0 because Godot Z-axis is opposite to FEAGI Z-axis
func generate_io_coordinates_for_brain_region(brain_region: BrainRegion) -> Dictionary:
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	var conflict_areas = _get_conflict_cortical_areas()
	
	# FEAGI coordinates = front-left corner (lowest x,y,z) - NO extra offsets
	
	var result = {
		"region_id": brain_region.region_ID,
		"region_coordinates": brain_region.coordinates_3D,
		"inputs": [],
		"outputs": [],
		"conflicts": []
	}
	
	# Calculate base positioning - brain region coordinates are the LOWEST corner (minimum x,y,z)
	var region_origin = Vector3(brain_region.coordinates_3D)  # Starting point, not center
	
	# FRONT-LEFT CORNER POSITIONING - Everything uses lowest x,y,z coordinates
	# Calculate plate sizes for positioning
	var input_plate_size = _calculate_plate_size_for_areas(input_areas, "INPUT")
	var output_plate_size = _calculate_plate_size_for_areas(output_areas, "OUTPUT")
	var conflict_plate_size = _calculate_plate_size_for_areas(conflict_areas, "CONFLICT")
	
	# INPUT PLATE: Areas start at plate FRONT edge (viewer side), extend inward (toward +Z in FEAGI, which is -Z in Godot)
	var input_start_x = PLATE_SIDE_MARGIN  # Margin from left edge
	var input_start_y = AREA_ABOVE_PLATE_GAP  # Margin from bottom edge  
	var input_start_z = PLATE_FRONT_BACK_MARGIN  # Positive margin inside the front edge
	
	# OUTPUT PLATE: Areas start at plate FRONT edge, extend inward
	var output_plate_x = input_plate_size.x + PLATE_GAP
	var output_start_x = output_plate_x + PLATE_SIDE_MARGIN
	var output_start_y = AREA_ABOVE_PLATE_GAP
	var output_start_z = PLATE_FRONT_BACK_MARGIN  # Start just behind the front edge
	
	# CONFLICT PLATE: Areas start at plate FRONT edge, extend inward 
	var conflict_plate_x = output_plate_x + output_plate_size.x + PLATE_GAP
	var conflict_start_x = conflict_plate_x + PLATE_SIDE_MARGIN
	var conflict_start_y = AREA_ABOVE_PLATE_GAP
	var conflict_start_z = PLATE_FRONT_BACK_MARGIN  # Start just behind the front edge
	
	var current_input_x = input_start_x  # Start at plate front-left + margin
	for i in input_areas.size():
		var area = input_areas[i]
		var area_size = Vector3(area.dimensions_3D)
		
		# Position area: FRONT-LEFT CORNER positioning (lowest x,y,z)
		var area_front_left_x = current_input_x
		var area_front_left_y = input_start_y
		var area_front_left_z = input_start_z
		
		# Convert front-left corner to CENTER coordinates in FEAGI (Godot flip happens later)
		var area_center_x = area_front_left_x + area_size.x / 2.0
		var area_center_y = area_front_left_y + area_size.y / 2.0  
		var area_center_z = area_front_left_z + area_size.z / 2.0
		
		var new_position = region_origin + Vector3(area_center_x, area_center_y, area_center_z)
		
		# Move to next area position: current_x + area_width + buffer
		current_input_x += area_size.x + AREA_BUFFER_DISTANCE
		
		var input_data = {
			"area_id": area.cortical_ID,
			"area_type": area.type_as_string,
			"original_coordinates": area.coordinates_3D,
			"new_coordinates": Vector3i(new_position)
		}
		result.inputs.append(input_data)
		
	
	var current_output_x = output_start_x  # Start at output plate front-left + margin
	for i in output_areas.size():
		var area = output_areas[i]
		var area_size = Vector3(area.dimensions_3D)
		
		# Position area: FRONT-LEFT CORNER positioning (lowest x,y,z)
		var area_front_left_x = current_output_x
		var area_front_left_y = output_start_y
		var area_front_left_z = output_start_z
		
		# Convert front-left corner to CENTER coordinates in FEAGI (Godot flip happens later)
		var area_center_x = area_front_left_x + area_size.x / 2.0
		var area_center_y = area_front_left_y + area_size.y / 2.0
		var area_center_z = area_front_left_z + area_size.z / 2.0
		
		var new_position = region_origin + Vector3(area_center_x, area_center_y, area_center_z)
		
		# Move to next area position: current_x + area_width + buffer
		current_output_x += area_size.x + AREA_BUFFER_DISTANCE
		
		var output_data = {
			"area_id": area.cortical_ID,
			"area_type": area.type_as_string, 
			"original_coordinates": area.coordinates_3D,
			"new_coordinates": Vector3i(new_position)
		}
		result.outputs.append(output_data)
		
	
	# CONFLICT PLATE: Process areas that appear in both inputs and outputs
	var current_conflict_x = conflict_start_x  # Start at conflict plate front-left + margin
	for i in conflict_areas.size():
		var area_c = conflict_areas[i]
		var area_size_c = Vector3(area_c.dimensions_3D)
		
		# Position area exactly like input/output: FRONT-LEFT corner then convert to center
		var area_front_left_x = current_conflict_x
		var area_front_left_y = conflict_start_y
		var area_front_left_z = conflict_start_z
		
		var area_center_x = area_front_left_x + area_size_c.x / 2.0
		var area_center_y = area_front_left_y + area_size_c.y / 2.0
		var area_center_z = area_front_left_z + area_size_c.z / 2.0
		
		var new_position_c = region_origin + Vector3(area_center_x, area_center_y, area_center_z)
		
		# Move to next area position: current_x + area_width + buffer
		current_conflict_x += area_size_c.x + AREA_BUFFER_DISTANCE
		
		var conflict_data = {
			"area_id": area_c.cortical_ID,
			"area_type": area_c.type_as_string, 
			"original_coordinates": area_c.coordinates_3D,
			"new_coordinates": Vector3i(new_position_c)
		}
		result.conflicts.append(conflict_data)
		
	
	
	return result

## Force refresh of all existing brain regions to apply new positioning logic
static func refresh_all_brain_regions_positioning() -> void:
	print("🔄 REFRESHING all existing brain region positioning with new plate alignment...")
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		var all_nodes = scene_tree.get_nodes_in_group("brain_regions")
		if all_nodes.is_empty():
			# Fallback: search the entire scene tree
			all_nodes = _find_all_brain_region_nodes(scene_tree.current_scene)
		
		print("  📊 Found %d brain region nodes to refresh" % all_nodes.size())
		for node in all_nodes:
			if node.has_method("_recalculate_plates_and_positioning_after_dimension_change") and node.get_script() and node.get_script().get_global_name() == "UI_BrainMonitor_BrainRegion3D":
				var brain_region_3d = node
				print("  🔧 Refreshing positioning for region: %s" % brain_region_3d.name)
				brain_region_3d._recalculate_plates_and_positioning_after_dimension_change()

## Helper to find all brain region nodes in scene tree
static func _find_all_brain_region_nodes(node: Node) -> Array:
	var brain_regions = []
	if node.has_method("_recalculate_plates_and_positioning_after_dimension_change") and node.get_script() and node.get_script().get_global_name() == "UI_BrainMonitor_BrainRegion3D":
		brain_regions.append(node)
	for child in node.get_children():
		brain_regions.append_array(_find_all_brain_region_nodes(child))
	return brain_regions

## DEBUG: Manually check label positions
func debug_label_positions() -> void:
	# Label debugging disabled to reduce log spam
	pass

## Returns the generated I/O coordinates for this brain region
func get_generated_io_coordinates() -> Dictionary:
	return _generated_io_coordinates

## Setup the 3D brain region visualization
func setup(brain_region: BrainRegion) -> void:
	
	_log_io_area_dimensions(brain_region)
	
	# 🚨 CRITICAL FIX: Set _representing_region BEFORE coordinate generation 
	# because I/O detection functions depend on it!
	_representing_region = brain_region
	
	_generated_io_coordinates = generate_io_coordinates_for_brain_region(brain_region)
	name = "BrainRegion3D_" + brain_region.region_ID
	
	# Create frame structure
	_create_3d_plate()
	_create_containers()
	
	# Populate with cortical areas
	_populate_cortical_areas()

	# Deferred hydration check: ensure I/O areas are properly detected and displayed
	call_deferred("_deferred_io_verification_and_hydration")
	
	# Connect to region signals for dynamic updates
	_representing_region.cortical_area_added_to_region.connect(_on_cortical_area_added)
	_representing_region.cortical_area_removed_from_region.connect(_on_cortical_area_removed)
	_representing_region.coordinates_3D_updated.connect(_update_position)
	_representing_region.friendly_name_updated.connect(_update_frame_label)
	
	# Connect to connection monitoring for dynamic I/O status changes
	_start_connection_monitoring()
	
	# Set initial position using FEAGI coordinates
	var coords = _representing_region.coordinates_3D
	var distance_from_origin = Vector3(coords).length()
	
	if distance_from_origin > 100.0:
		print("  ⚠️  WARNING: Brain region positioned very far from origin!")
		print("    📍 Coordinates: %s" % coords)
		print("    📏 Distance from origin: %.1f units" % distance_from_origin)
		print("    💡 This might make the brain region invisible in the camera view.")
		print("    💡 Try moving the camera or adjusting the brain region coordinates.")
	
	_update_position(_representing_region.coordinates_3D)

	# Defer a post-build sync to ensure all child renderers and plates are fully in tree
	call_deferred("_post_initial_build_sync")

## Deferred I/O verification and hydration: ensures areas are properly displayed after setup
func _deferred_io_verification_and_hydration() -> void:
	await get_tree().process_frame
	await get_tree().process_frame  # Wait for all initial setup to complete
	
	if not _representing_region or _representing_region.contained_cortical_areas.size() == 0:
		print("  ⏭️ HYDRATION: No contained areas in region, skipping hydration")
		return
	
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	var has_no_io_areas = (input_areas.size() == 0 and output_areas.size() == 0)
	var has_missing_visualizations = false
	
	# Check if we have I/O areas but missing visualizations on plates
	for area in input_areas:
		if area.cortical_ID not in _cortical_area_visualizations:
			has_missing_visualizations = true
			break
	
	if not has_missing_visualizations:
		for area in output_areas:
			if area.cortical_ID not in _cortical_area_visualizations:
				has_missing_visualizations = true
				break
	
	# Trigger hydration if no I/O areas found OR missing visualizations
	if has_no_io_areas or has_missing_visualizations:
		print("  🔄 HYDRATION: Region %s needs I/O refresh - no_io: %s, missing_viz: %s" % [_representing_region.region_ID, has_no_io_areas, has_missing_visualizations])
		print("    - Found %d inputs, %d outputs" % [input_areas.size(), output_areas.size()])
		print("    - Have %d visualizations on plates" % _cortical_area_visualizations.size())
		
		# Use local cache refresh instead of network request for better reliability
		FeagiCore.feagi_local_cache._refresh_single_brain_region_cache(_representing_region)
		
		# Regenerate coordinates and repopulate
		_generated_io_coordinates = generate_io_coordinates_for_brain_region(_representing_region)
		
		# Get current I/O areas after cache refresh to determine what should be kept
		var updated_input_areas = _get_input_cortical_areas()
		var updated_output_areas = _get_output_cortical_areas()
		var updated_io_ids: Array[String] = []
		
		for area in updated_input_areas:
			updated_io_ids.append(area.cortical_ID)
		for area in updated_output_areas:
			updated_io_ids.append(area.cortical_ID)
		
		# Only clear visualizations that are no longer I/O areas
		for child in _input_areas_container.get_children():
			var area_id = child.name.replace("CA_", "")  # Extract cortical ID from node name
			if area_id not in updated_io_ids:
				print("    🧹 HYDRATION: Removing outdated input visualization: %s" % area_id)
				child.queue_free()
				_cortical_area_visualizations.erase(area_id)
		
		for child in _output_areas_container.get_children():
			var area_id = child.name.replace("CA_", "")  # Extract cortical ID from node name  
			if area_id not in updated_io_ids:
				print("    🧹 HYDRATION: Removing outdated output visualization: %s" % area_id)
				child.queue_free()
				_cortical_area_visualizations.erase(area_id)
		
		print("    🔄 HYDRATION: Selective cleanup complete - keeping valid I/O visualizations")
		
		await get_tree().process_frame
		_populate_cortical_areas()
		
		# Force a comprehensive update
		_recalculate_plates_and_positioning_after_dimension_change()
		print("  ✅ HYDRATION: Completed I/O refresh for region %s" % _representing_region.region_ID)
	else:
		# Still do the post-initial build sync for consistency
		_post_initial_build_sync()

## Deferred one-time sync to eliminate startup race between plates and area renderers
func _post_initial_build_sync() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# Regenerate and apply to ensure consistency with dynamic path
	_generated_io_coordinates = generate_io_coordinates_for_brain_region(_representing_region)
	_recalculate_plates_and_positioning_after_dimension_change()

## Custom dimension update handler for I/O cortical areas on brain region plates
## Updates dimensions without overriding brain region positioning
func _on_io_cortical_area_dimensions_changed(new_dimensions: Vector3i, cortical_id: String) -> void:
	print("🔧 Brain region handling dimension update for I/O area %s: %s" % [cortical_id, new_dimensions])
	if _dimension_recalc_in_progress:
		print("⏳ Dimension recalc already in progress; skipping duplicate update for %s" % cortical_id)
		return
	_dimension_recalc_in_progress = true
	
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
	
	# COMPREHENSIVE PLATE UPDATE: Recalculate sizes and reposition all I/O areas
	print("    🔄 Comprehensive plate update after dimension change...")
	_recalculate_plates_and_positioning_after_dimension_change()
	_dimension_recalc_in_progress = false

## Comprehensive plate and positioning update after cortical area dimension changes
func _recalculate_plates_and_positioning_after_dimension_change() -> void:
	if not _representing_region:
		return
		
	
	# 1. Regenerate I/O coordinates with new dimensions (includes new plate size calculations)
	_generated_io_coordinates = generate_io_coordinates_for_brain_region(_representing_region)
	
	# 2. Remove entire existing RegionAssembly containers to avoid duplicates lingering
	if _frame_container:
		_frame_container.queue_free()
		_frame_container = null
	# Also remove any stray 'RegionAssembly' children left behind
	for direct_child in get_children():
		if direct_child is Node3D and direct_child.name == "RegionAssembly":
			direct_child.queue_free()
	await get_tree().process_frame

	# Also remove old click collision bodies attached directly to this node (if tied to previous sizes)
	for direct_child in get_children():
		if direct_child is StaticBody3D and (direct_child.name.ends_with("ClickArea")):
			direct_child.queue_free()
	# Process removal of click areas
	await get_tree().process_frame
	
	# 3. Recreate plates with new sizes
	# Recreate the main frame container before adding plates
	_frame_container = Node3D.new()
	_frame_container.name = "RegionAssembly"
	add_child(_frame_container)
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	var conflict_areas = _get_conflict_cortical_areas()

	# Detect areas used as both input and output; mark conflict
	var input_ids_update: Array[StringName] = []
	for a in input_areas:
		input_ids_update.append(a.cortical_ID)
	var output_ids_update: Array[StringName] = []
	for a in output_areas:
		output_ids_update.append(a.cortical_ID)
	var conflict := false
	for id in input_ids_update:
		if id in output_ids_update:
			conflict = true
			break
	
	# Calculate new plate sizes (always create input/output; conflict only if exists)
	var input_plate_size = _calculate_plate_size_for_areas(input_areas, "INPUT")
	var output_plate_size = _calculate_plate_size_for_areas(output_areas, "OUTPUT")
	var conflict_plate_size = _calculate_plate_size_for_areas(conflict_areas, "CONFLICT")
	
	# Create new plates with updated sizes (20% opacity to match user setting)
	var input_color = Color(0.0, 0.6, 0.0, 0.2)  # Brighter green for input
	var input_plate
	if input_areas.size() > 0:
		input_plate = _create_single_plate(input_plate_size, "InputPlate", input_color)
	else:
		input_plate = _create_wireframe_placeholder_plate(PLACEHOLDER_PLATE_SIZE, "InputPlate", input_color)
	input_plate.position.x = input_plate_size.x / 2.0
	input_plate.position.y = PLATE_HEIGHT / 2.0  
	_frame_container.add_child(input_plate)
	# If conflict, attach hover warning
	if conflict:
		_attach_hover_warning(input_plate, "Area used as both INPUT and OUTPUT in this region")
	
	var output_color = Color(0.0, 0.4, 0.0, 0.2)  # Darker green for output with 20% opacity
	if conflict:
		# Set plates to reddish when conflict detected
		input_color = Color(0.6, 0.0, 0.0, 0.25)
		output_color = Color(0.6, 0.0, 0.0, 0.25)
	var output_plate
	if output_areas.size() > 0:
		output_plate = _create_single_plate(output_plate_size, "OutputPlate", output_color)
	else:
		output_plate = _create_wireframe_placeholder_plate(PLACEHOLDER_PLATE_SIZE, "OutputPlate", output_color)
	var output_front_left_x = input_plate_size.x + PLATE_GAP
	output_plate.position.x = output_front_left_x + output_plate_size.x / 2.0
	output_plate.position.y = PLATE_HEIGHT / 2.0
	_frame_container.add_child(output_plate)
	if conflict:
		_attach_hover_warning(output_plate, "Area used as both INPUT and OUTPUT in this region")

	# Create conflict plate to the RIGHT of the output plate (only if conflicts exist)
	var conflict_plate = null
	if conflict_areas.size() > 0:
		var conflict_color = Color(0.8, 0.0, 0.0, 0.2)
		# Reuse existing conflict plate if present to avoid duplicates
		var existing_conflict: MeshInstance3D = _frame_container.get_node_or_null("ConflictPlate")
		if existing_conflict:
			# Update mesh size and material
			var existing_mesh := existing_conflict.mesh
			if existing_mesh is BoxMesh:
				(existing_mesh as BoxMesh).size = Vector3(conflict_plate_size.x, 1.0, conflict_plate_size.z)
			# Update color
			if existing_conflict.material_override is StandardMaterial3D:
				(existing_conflict.material_override as StandardMaterial3D).albedo_color = conflict_color
			conflict_plate = existing_conflict
		else:
			conflict_plate = _create_single_plate(conflict_plate_size, "ConflictPlate", conflict_color)
		# Recompute front-left based on current (possibly changed) output size to prevent collisions
		var conflict_front_left_x = input_plate_size.x + PLATE_GAP + output_plate_size.x + PLATE_GAP
		conflict_plate.position.x = conflict_front_left_x + conflict_plate_size.x / 2.0
		conflict_plate.position.y = PLATE_HEIGHT / 2.0
		if conflict_plate.get_parent() != _frame_container:
			_frame_container.add_child(conflict_plate)

	# Align plate global Z to match front-edge at brain region Z
	var region_world = Vector3(_representing_region.coordinates_3D.x, _representing_region.coordinates_3D.y, -_representing_region.coordinates_3D.z)
	if input_plate:
		var input_center_z = region_world.z - input_plate_size.z / 2.0
		input_plate.global_position.z = input_center_z
	if output_plate:
		var output_center_z = region_world.z - output_plate_size.z / 2.0
		output_plate.global_position.z = output_center_z
	if conflict_plate:
		var conflict_center_z = region_world.z - conflict_plate_size.z / 2.0
		conflict_plate.global_position.z = conflict_center_z
	
	# Create or update MOTHER PLATE (binder) under all plates
	var actual_input_width = input_plate_size.x if input_areas.size() > 0 else PLACEHOLDER_PLATE_SIZE.x
	var actual_output_width = output_plate_size.x if output_areas.size() > 0 else PLACEHOLDER_PLATE_SIZE.x
	var mother_total_width = actual_input_width + PLATE_GAP + actual_output_width
	if conflict_areas.size() > 0:
		var actual_conflict_width = conflict_plate_size.x
		mother_total_width += PLATE_GAP + actual_conflict_width
	var mother_size = Vector3(mother_total_width, PLATE_HEIGHT, 1.0)
	var mustard = Color(0.415, 0.343, 0.076, 0.725)
	var mother_plate: MeshInstance3D = _frame_container.get_node_or_null("MotherPlate")
	if mother_plate == null:
		mother_plate = _create_mother_plate(mother_size, "MotherPlate", mustard)
		_frame_container.add_child(mother_plate)
	else:
		var existing_mesh := mother_plate.mesh
		if existing_mesh is BoxMesh:
			(existing_mesh as BoxMesh).size = mother_size
		if mother_plate.material_override is StandardMaterial3D:
			(mother_plate.material_override as StandardMaterial3D).albedo_color = mustard
	# Position mother plate centered across all plates; align front edges at region Z
	mother_plate.position.x = mother_total_width / 2.0
	mother_plate.position.y = PLATE_HEIGHT / 2.0 - 2.0
	var mother_center_z = region_world.z - 0.5
	mother_plate.global_position.z = mother_center_z
	
	# Update clickable collision areas to match new plate sizes/positions
	_add_collision_bodies_for_clicking(input_plate_size, output_plate_size, conflict_plate_size, conflict_areas.size() > 0, PLATE_GAP)

	# Recenter label across all plates (including conflict if present)
	call_deferred("_update_label_position_after_refresh")

	# 4. Reposition all I/O cortical areas using new coordinates
	for cortical_id in _cortical_area_visualizations.keys():
		var cortical_viz = _cortical_area_visualizations[cortical_id]
		
		# Find new position for this cortical area
		var found_new_position = false
		
		# Check inputs first
		for area_data in _generated_io_coordinates.inputs:
			if area_data.area_id == cortical_id:
				var absolute_feagi_coords = Vector3(area_data.new_coordinates)
				var brain_region_coords = Vector3(_representing_region.coordinates_3D)
				var relative_position = absolute_feagi_coords - brain_region_coords
				_reposition_cortical_area_on_plate(cortical_viz, relative_position, true)  # true = input
				found_new_position = true
				break
		
		# Check outputs if not found in inputs
		if not found_new_position:
			for area_data in _generated_io_coordinates.outputs:
				if area_data.area_id == cortical_id:
					var absolute_feagi_coords = Vector3(area_data.new_coordinates)
					var brain_region_coords = Vector3(_representing_region.coordinates_3D)
					var relative_position = absolute_feagi_coords - brain_region_coords
					_reposition_cortical_area_on_plate(cortical_viz, relative_position, false)  # false = output
					found_new_position = true
					break

		# Check conflicts if not found in inputs or outputs
		if not found_new_position:
			for area_data in _generated_io_coordinates.conflicts:
				if area_data.area_id == cortical_id:
					var absolute_feagi_coords = Vector3(area_data.new_coordinates)
					var brain_region_coords = Vector3(_representing_region.coordinates_3D)
					var relative_position = absolute_feagi_coords - brain_region_coords
					# Use output-style Z flip logic inside reposition helper
					_reposition_cortical_area_on_plate(cortical_viz, relative_position, false)
					found_new_position = true
					break
		
	
	# 5. Update region label position attached to MotherPlate
	if _region_name_label:
		var mother: MeshInstance3D = _frame_container.get_node_or_null("MotherPlate") as MeshInstance3D
		if mother != null:
			if _region_name_label.get_parent() != mother:
				var prev_parent = _region_name_label.get_parent()
				if prev_parent != null:
					prev_parent.remove_child(_region_name_label)
			mother.add_child(_region_name_label)
			# Place just below bezel and slightly in front of its front face
			if mother.mesh is BoxMesh:
				var bezel_front = (mother.mesh as BoxMesh).size.z / 2.0
				_region_name_label.position = Vector3(0.0, -(PLATE_HEIGHT / 2.0) - 0.25, -(bezel_front + 0.05))
			else:
				_region_name_label.position = Vector3(0.0, -(PLATE_HEIGHT / 2.0) - 0.25, -0.05)
		else:
			var front_edge_world_z = -_representing_region.coordinates_3D.z
			_region_name_label.global_position = Vector3(global_position.x, global_position.y - 0.5, front_edge_world_z - 1.0)
		print("    📍 Label repositioned near front edge: world pos (%.1f, %.1f, %.1f)" % [_region_name_label.global_position.x, _region_name_label.global_position.y, _region_name_label.global_position.z])
	

## Repositions a single cortical area on its plate using new relative coordinates
func _reposition_cortical_area_on_plate(cortical_viz: UI_BrainMonitor_CorticalArea, new_position: Vector3, is_input: bool) -> void:
	# Convert brain region FEAGI coordinates to Godot world position
	var brain_region_coords = _representing_region.coordinates_3D
	var brain_region_world_pos = Vector3(brain_region_coords.x, brain_region_coords.y, -brain_region_coords.z)
	
	# Calculate desired world position; new_position is FEAGI-relative
	# FEAGI -> Godot conversion: (x, y, -z)
	var desired_world_pos = brain_region_world_pos + Vector3(new_position.x, new_position.y, -new_position.z)

	# Ensure cortical area's CENTER matches generated coordinate (relative FEAGI new_position)
	# We already converted FEAGI new_position with Z flip above; do not override with a second rule
	
	# Position the renderers at the new location (now snapped to plate Z)
	if cortical_viz._dda_renderer != null and cortical_viz._dda_renderer._static_body != null:
		cortical_viz._dda_renderer._static_body.global_position = desired_world_pos
		if cortical_viz._dda_renderer._friendly_name_label != null:
			cortical_viz._dda_renderer._friendly_name_label.global_position = desired_world_pos + Vector3(0, 1.0, 0)
	
	if cortical_viz._directpoints_renderer != null and cortical_viz._directpoints_renderer._static_body != null:
		cortical_viz._directpoints_renderer._static_body.global_position = desired_world_pos
		if cortical_viz._directpoints_renderer._friendly_name_label != null:
			cortical_viz._directpoints_renderer._friendly_name_label.global_position = desired_world_pos + Vector3(0, 1.0, 0)

func _get_plate_global_z(is_input: bool) -> float:
	# Fetch the exact Z from the plate nodes to avoid drift
	if _frame_container == null:
		return 0.0
	var plate_name = "InputPlate" if is_input else "OutputPlate"
	var plate_node = _frame_container.get_node_or_null(plate_name)
	if plate_node == null:
		return 0.0
	return (plate_node as Node3D).global_position.z

	# Debug: ensure plate and cortical area Z match exactly
	# var which = "INPUT" if is_input else "OUTPUT"
	# print("    🔧 Snapped %s cortical area Z to plate Z=%.2f" % [which, desired_world_pos.z])

## Creates the 3D plate structure underneath I/O cortical areas
func _create_3d_plate() -> void:
	# Get input/output/conflict areas for sizing
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	var conflict_areas = _get_conflict_cortical_areas()
	
	# FEAGI FRONT-LEFT CORNER positioning - no extra offsets
	# Plates positioned directly at brain region coordinates (front-left corner)
	
	# Calculate maximum depth for reference (not used for positioning)
	var max_input_depth = 0.0
	for area in input_areas:
		max_input_depth = max(max_input_depth, area.dimensions_3D.z)
	var max_output_depth = 0.0
	for area in output_areas:
		max_output_depth = max(max_output_depth, area.dimensions_3D.z)
	var max_conflict_depth = 0.0
	for area in conflict_areas:
		max_conflict_depth = max(max_conflict_depth, area.dimensions_3D.z)
	
	# Calculate sizes for each plate independently - CREATE ALL PLATES (conflict only if needed)
	var input_plate_size = _calculate_plate_size_for_areas(input_areas, "INPUT")
	var output_plate_size = _calculate_plate_size_for_areas(output_areas, "OUTPUT")
	var conflict_plate_size = _calculate_plate_size_for_areas(conflict_areas, "CONFLICT")
	
	var plate_spacing = 1.0  # Gap between input and output plates
	
	# Work directly with front-edge positioning (no center calculations)
	# Godot requires center positioning, so we'll apply the offset when setting position
	
	
	# Create the main frame container
	_frame_container = Node3D.new()
	_frame_container.name = "RegionAssembly"
	add_child(_frame_container)
	
	# INPUT PLATE: Front-left corner at brain region coordinates (0,0,0 relative)
	var input_color = Color(0.0, 0.6, 0.0, 0.2)  # Light green with opacity
	var input_plate
	if input_areas.size() > 0:
		input_plate = _create_single_plate(input_plate_size, "InputPlate", input_color)
	else:
		input_plate = _create_wireframe_placeholder_plate(PLACEHOLDER_PLATE_SIZE, "InputPlate", input_color)
	# FRONT-LEFT CORNER positioning - Godot centers meshes, so adjust by half-size
	input_plate.position.x = input_plate_size.x / 2.0  # Half-width to align front-left corner at origin
	input_plate.position.y = PLATE_HEIGHT / 2.0  # Half-height to align bottom at origin
	# Use global Z set through transform later to allow querying exact plate Z
	_frame_container.add_child(input_plate)

	# OUTPUT PLATE: Positioned at input_width + gap from brain region front-left corner
	var output_color = Color(0.0, 0.4, 0.0, 0.2)  # Darker green with opacity
	var output_plate
	if output_areas.size() > 0:
		output_plate = _create_single_plate(output_plate_size, "OutputPlate", output_color)
	else:
		output_plate = _create_wireframe_placeholder_plate(PLACEHOLDER_PLATE_SIZE, "OutputPlate", output_color)
	# FRONT-LEFT CORNER positioning - Output plate starts at input_width + gap
	var output_front_left_x = input_plate_size.x + PLATE_GAP
	output_plate.position.x = output_front_left_x + output_plate_size.x / 2.0  # Godot center adjustment
	output_plate.position.y = PLATE_HEIGHT / 2.0  # Same Y as input plate (Godot center)
	# Use global Z set through transform later to allow querying exact plate Z
	_frame_container.add_child(output_plate)
	
	# CONFLICT PLATE: Only create if there are conflicted areas  
	var conflict_plate = null
	if conflict_areas.size() > 0:
		var conflict_color = Color(0.8, 0.0, 0.0, 0.2)  # Red with opacity
		conflict_plate = _create_single_plate(conflict_plate_size, "ConflictPlate", conflict_color)
		# FRONT-LEFT CORNER positioning - Must match coordinate generation logic
		var conflict_plate_x = input_plate_size.x + PLATE_GAP + output_plate_size.x + PLATE_GAP  # Same as coordinate generation
		conflict_plate.position.x = conflict_plate_x + conflict_plate_size.x / 2.0  # Godot center adjustment
		conflict_plate.position.y = PLATE_HEIGHT / 2.0  # Same Y as other plates (Godot center)
		# Use global Z set through transform later to allow querying exact plate Z
		_frame_container.add_child(conflict_plate)

	# After adding plates, set their global Z so front edges align at brain region Z
	var region_world = Vector3(_representing_region.coordinates_3D.x, _representing_region.coordinates_3D.y, -_representing_region.coordinates_3D.z)
	if input_plate:
		var input_center_z = region_world.z - input_plate_size.z / 2.0
		if input_plate.is_inside_tree():
			input_plate.global_position.z = input_center_z
		else:
			input_plate.position.z = input_center_z
	if output_plate:
		var output_center_z = region_world.z - output_plate_size.z / 2.0
		if output_plate.is_inside_tree():
			output_plate.global_position.z = output_center_z
		else:
			output_plate.position.z = output_center_z
	if conflict_plate:
		var conflict_center_z = region_world.z - conflict_plate_size.z / 2.0
		if conflict_plate.is_inside_tree():
			conflict_plate.global_position.z = conflict_center_z
		else:
			conflict_plate.position.z = conflict_center_z

	# Create or update MOTHER PLATE (binder) under all plates
	var actual_input_width_ = input_plate_size.x if input_areas.size() > 0 else PLACEHOLDER_PLATE_SIZE.x
	var actual_output_width_ = output_plate_size.x if output_areas.size() > 0 else PLACEHOLDER_PLATE_SIZE.x
	var mother_total_width_ = actual_input_width_ + PLATE_GAP + actual_output_width_
	if conflict_areas.size() > 0:
		var actual_conflict_width_ = conflict_plate_size.x
		mother_total_width_ += PLATE_GAP + actual_conflict_width_
	var mother_size_ = Vector3(mother_total_width_, PLATE_HEIGHT, 1.0)
	var mustard_ = Color(0.827, 0.706, 0.196, 1.0)
	var mother_plate_ : MeshInstance3D = _frame_container.get_node_or_null("MotherPlate")
	if mother_plate_ == null:
		mother_plate_ = _create_mother_plate(mother_size_, "MotherPlate", mustard_)
		_frame_container.add_child(mother_plate_)
	else:
		var existing_mesh_ := mother_plate_.mesh
		if existing_mesh_ is BoxMesh:
			(existing_mesh_ as BoxMesh).size = mother_size_
		if mother_plate_.material_override is StandardMaterial3D:
			(mother_plate_.material_override as StandardMaterial3D).albedo_color = mustard_
	mother_plate_.position.x = mother_total_width_ / 2.0
	mother_plate_.position.y = PLATE_HEIGHT / 2.0 - 2.0
	var mother_center_z_ = region_world.z - 0.5
	if mother_plate_.is_inside_tree():
		mother_plate_.global_position.z = mother_center_z_
	else:
		mother_plate_.position.z = mother_center_z_

	# Create region name label (white, large) and place it below the bezel
	_region_name_label = Label3D.new()
	_region_name_label.name = "RegionNameLabel"
	_region_name_label.text = _representing_region.friendly_name
	_region_name_label.font_size = 320  # Larger than cortical area labels for visibility
	_region_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
	_region_name_label.fixed_size = true  # Keep readable regardless of distance
	_region_name_label.no_depth_test = true  # Always draw on top
	_region_name_label.outline_render_priority = 1
	_region_name_label.outline_size = 4
	_region_name_label.modulate = Color.WHITE
	_region_name_label.outline_modulate = Color(0, 0, 0, 1)
	_region_name_label.render_priority = 10
	_region_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Attach to frame container and position using world coordinates
	_frame_container.add_child(_region_name_label)
	# Center X across all plates
	var total_width = input_plate_size.x + PLATE_GAP + output_plate_size.x
	if conflict_areas.size() > 0:
		total_width += PLATE_GAP + conflict_plate_size.x
	var center_x = total_width / 2.0
	# Y just below bezel if present; otherwise a small offset below plates
	var bezel: MeshInstance3D = _frame_container.get_node_or_null("MotherPlate") as MeshInstance3D
	var label_y_world = global_position.y - 0.5
	# Z in front of bezel front face (or front edge if bezel missing)
	var label_z_world: float
	if bezel != null and bezel.mesh is BoxMesh:
		label_y_world = bezel.global_position.y - (PLATE_HEIGHT / 2.0) - 0.25
		var bezel_front_z = bezel.global_position.z - ((bezel.mesh as BoxMesh).size.z / 2.0)
		label_z_world = bezel_front_z - 0.05
	else:
		var front_edge_world_z = -_representing_region.coordinates_3D.z
		label_z_world = front_edge_world_z - 0.05
	_region_name_label.global_position = Vector3(global_position.x + center_x, label_y_world, label_z_world)
	_region_name_label.visible = true
	
	
	# Add collision bodies for click detection (as direct children for proper detection)
	_add_collision_bodies_for_clicking(input_plate_size, output_plate_size, conflict_plate_size, conflict_areas.size() > 0, PLATE_GAP)
	
	var plate_count = 2 + (1 if conflict_areas.size() > 0 else 0)
	
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
	plate_material.albedo_color = plate_color  # Use the actual alpha value from plate_color parameter
	plate_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # Enable alpha transparency
	plate_material.flags_unshaded = true
	plate_material.flags_transparent = true
	plate_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plate_material.no_depth_test = false
	plate_material.flags_do_not_receive_shadows = true
	plate_material.flags_disable_ambient_light = true
	plate_mesh_instance.material_override = plate_material
	
	# Note: StaticBody3D will be added separately as direct child of BrainRegion3D for proper click detection
	
	return plate_mesh_instance

func _attach_hover_warning(plate_node: MeshInstance3D, warning_text: String) -> void:
	# Attach a simple Label3D as a child and toggle visibility on hover
	var warn = Label3D.new()
	warn.name = "HoverWarning"
	warn.text = warning_text
	warn.visible = false
	warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.modulate = Color(1, 0.6, 0.6, 0.9)
	warn.position = Vector3(0, 2.0, 0)
	plate_node.add_child(warn)

## Creates a visible placeholder using 12 thick edge rods for empty input/output plates
func _create_wireframe_placeholder_plate(plate_size: Vector3, plate_name: String, plate_color: Color) -> MeshInstance3D:
	# Container node; children will form the edges
	var plate_mesh_instance = MeshInstance3D.new()
	plate_mesh_instance.name = plate_name + "_Wireframe"
	plate_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Half dimensions for positioning
	var half_x = plate_size.x / 2.0
	var half_y = plate_size.y / 2.0
	var half_z = plate_size.z / 2.0
	
	# Unshaded emissive edge material for high visibility
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
	
	# Edge thickness
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

## Creates a solid "mother" plate used as a binder under all region plates
func _create_mother_plate(size: Vector3, plate_name: String, plate_color: Color) -> MeshInstance3D:
	var plate_mesh_instance = MeshInstance3D.new()
	plate_mesh_instance.name = plate_name
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	plate_mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = plate_color
	material.flags_unshaded = true
	material.flags_transparent = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material.flags_do_not_receive_shadows = true
	material.flags_disable_ambient_light = true
	plate_mesh_instance.material_override = material
	plate_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	return plate_mesh_instance

## Adds collision bodies for clicking detection (plates and label)
func _add_collision_bodies_for_clicking(input_plate_size: Vector3, output_plate_size: Vector3, conflict_plate_size: Vector3, has_conflict_plate: bool, plate_gap: float) -> void:
	# Create collision body for INPUT PLATE - Front-left corner positioning
	var input_collision = StaticBody3D.new()
	input_collision.name = "InputPlateClickArea"
	# Ensure pickable by ray: set common layer/mask (default 1)
	input_collision.collision_layer = 1
	input_collision.collision_mask = 1
	input_collision.position.x = input_plate_size.x / 2.0  # Same as plate center position
	input_collision.position.y = PLATE_HEIGHT / 2.0  # Same as plate center position
	input_collision.position.z = input_plate_size.z / 2.0  # Same as plate center position
	
	var input_collision_shape = CollisionShape3D.new()
	input_collision_shape.name = "CollisionShape"
	var input_box_shape = BoxShape3D.new()
	# Slightly thicker to guarantee hits
	input_box_shape.size = Vector3(input_plate_size.x, 2.0, input_plate_size.z)
	input_collision_shape.shape = input_box_shape
	input_collision.add_child(input_collision_shape)
	add_child(input_collision)  # Direct child of BrainRegion3D
	# Snap collider center to the actual plate's global center (ensures exact Z match)
	var input_plate_node: Node3D = get_node_or_null("RegionAssembly/InputPlate") as Node3D
	if input_plate_node == null:
		input_plate_node = get_node_or_null("RegionAssembly/InputPlate_Wireframe") as Node3D
	if input_plate_node != null:
		if input_plate_node.is_inside_tree():
			input_collision.global_position = input_plate_node.global_position
		else:
			input_collision.position = input_plate_node.position
	# Hover wiring for input plate
	if has_node("RegionAssembly/InputPlate"):
		var plate: MeshInstance3D = get_node("RegionAssembly/InputPlate")
		var warn: Label3D = plate.get_node_or_null("HoverWarning")
		if warn:
			input_collision.mouse_entered.connect(func(): warn.visible = true)
			input_collision.mouse_exited.connect(func(): warn.visible = false)
		# Show overlay plate context
		input_collision.mouse_entered.connect(func():
			var bm: UI_BrainMonitor_3DScene = BV.UI.get_active_brain_monitor()
			if bm and bm._UI_layer_for_BM:
				bm._UI_layer_for_BM.show_plate_hover(_representing_region.friendly_name, "Input plate")
		)
		input_collision.mouse_exited.connect(func():
			var bm: UI_BrainMonitor_3DScene = BV.UI.get_active_brain_monitor()
			if bm and bm._UI_layer_for_BM:
				bm._UI_layer_for_BM.clear_plate_hover()
		)
	
	# Create collision body for OUTPUT PLATE - Front-left corner positioning
	var output_collision = StaticBody3D.new()
	output_collision.name = "OutputPlateClickArea"
	output_collision.collision_layer = 1
	output_collision.collision_mask = 1
	var output_front_left_x = input_plate_size.x + plate_gap
	output_collision.position.x = output_front_left_x + output_plate_size.x / 2.0  # Same as plate position
	output_collision.position.y = PLATE_HEIGHT / 2.0  # Same as plate position
	output_collision.position.z = output_plate_size.z / 2.0  # Same as plate position
	
	var output_collision_shape = CollisionShape3D.new()
	output_collision_shape.name = "CollisionShape"
	var output_box_shape = BoxShape3D.new()
	output_box_shape.size = Vector3(output_plate_size.x, 2.0, output_plate_size.z)
	output_collision_shape.shape = output_box_shape
	output_collision.add_child(output_collision_shape)
	add_child(output_collision)  # Direct child of BrainRegion3D
	# Snap collider center to the actual plate's global center (ensures exact Z match)
	var output_plate_node: Node3D = get_node_or_null("RegionAssembly/OutputPlate") as Node3D
	if output_plate_node == null:
		output_plate_node = get_node_or_null("RegionAssembly/OutputPlate_Wireframe") as Node3D
	if output_plate_node != null:
		if output_plate_node.is_inside_tree():
			output_collision.global_position = output_plate_node.global_position
		else:
			output_collision.position = output_plate_node.position
	# Hover wiring for output plate
	if has_node("RegionAssembly/OutputPlate"):
		var plate_o: MeshInstance3D = get_node("RegionAssembly/OutputPlate")
		var warn_o: Label3D = plate_o.get_node_or_null("HoverWarning")
		if warn_o:
			output_collision.mouse_entered.connect(func(): warn_o.visible = true)
			output_collision.mouse_exited.connect(func(): warn_o.visible = false)
		# Show overlay plate context
		output_collision.mouse_entered.connect(func():
			var bm: UI_BrainMonitor_3DScene = BV.UI.get_active_brain_monitor()
			if bm and bm._UI_layer_for_BM:
				bm._UI_layer_for_BM.show_plate_hover(_representing_region.friendly_name, "Output plate")
		)
		output_collision.mouse_exited.connect(func():
			var bm: UI_BrainMonitor_3DScene = BV.UI.get_active_brain_monitor()
			if bm and bm._UI_layer_for_BM:
				bm._UI_layer_for_BM.clear_plate_hover()
		)
	
	# Create collision body for CONFLICT PLATE (if it exists)
	if has_conflict_plate:
		var conflict_collision = StaticBody3D.new()
		conflict_collision.name = "ConflictPlateClickArea"
		conflict_collision.collision_layer = 1
		conflict_collision.collision_mask = 1
		var conflict_plate_x = input_plate_size.x + plate_gap + output_plate_size.x + plate_gap  # Same as plate positioning
		conflict_collision.position.x = conflict_plate_x + conflict_plate_size.x / 2.0  # Same as plate position
		conflict_collision.position.y = PLATE_HEIGHT / 2.0  # Same as plate position
		conflict_collision.position.z = conflict_plate_size.z / 2.0  # Same as plate position
		
		var conflict_collision_shape = CollisionShape3D.new()
		conflict_collision_shape.name = "CollisionShape"
		var conflict_box_shape = BoxShape3D.new()
		conflict_box_shape.size = Vector3(conflict_plate_size.x, 2.0, conflict_plate_size.z)
		conflict_collision_shape.shape = conflict_box_shape
		conflict_collision.add_child(conflict_collision_shape)
		add_child(conflict_collision)  # Direct child of BrainRegion3D
		# Snap collider center to the actual plate's global center (ensures exact Z match)
		var conflict_plate_node: Node3D = get_node_or_null("RegionAssembly/ConflictPlate") as Node3D
		if conflict_plate_node != null:
			if conflict_plate_node.is_inside_tree():
				conflict_collision.global_position = conflict_plate_node.global_position
			else:
				conflict_collision.position = conflict_plate_node.position
		# Hover wiring for conflict plate
		if has_node("RegionAssembly/ConflictPlate"):
			var plate_c: MeshInstance3D = get_node("RegionAssembly/ConflictPlate")
			var warn_c: Label3D = plate_c.get_node_or_null("HoverWarning")
			if warn_c:
				conflict_collision.mouse_entered.connect(func(): warn_c.visible = true)
				conflict_collision.mouse_exited.connect(func(): warn_c.visible = false)
			# Show overlay plate context
			conflict_collision.mouse_entered.connect(func():
				var bm: UI_BrainMonitor_3DScene = BV.UI.get_active_brain_monitor()
				if bm and bm._UI_layer_for_BM:
					bm._UI_layer_for_BM.show_plate_hover(_representing_region.friendly_name, "Conflict plate")
			)
			conflict_collision.mouse_exited.connect(func():
				var bm: UI_BrainMonitor_3DScene = BV.UI.get_active_brain_monitor()
				if bm and bm._UI_layer_for_BM:
					bm._UI_layer_for_BM.clear_plate_hover()
			)
	
	# Create collision body for REGION LABEL
	var label_collision = StaticBody3D.new()
	label_collision.name = "RegionLabelClickArea"
	# Position collision same as label (centered across all plates)  
	var collision_total_width = input_plate_size.x + PLATE_GAP + output_plate_size.x
	if has_conflict_plate:
		collision_total_width += PLATE_GAP + conflict_plate_size.x  # Add conflict plate to total width
	var collision_center_x = collision_total_width / 2.0
	label_collision.position = Vector3(collision_center_x, -3.0, 2.0)  # Centered horizontally, 2 units closer to viewer
	
	var label_collision_shape = CollisionShape3D.new()
	label_collision_shape.name = "CollisionShape"
	var label_box_shape = BoxShape3D.new()
	label_box_shape.size = Vector3(8.0, 2.0, 1.0)  # Reasonable clickable area around text
	label_collision_shape.shape = label_box_shape
	label_collision.add_child(label_collision_shape)
	add_child(label_collision)  # Direct child of BrainRegion3D
	

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
	
	# If no areas, create yellow placeholder
	if areas.size() == 0:
		return PLACEHOLDER_PLATE_SIZE
	
	# Calculate width: sum of all area widths + buffers + margins
	var total_width = 0.0
	var max_depth = 0.0
	
	for area in areas:
		total_width += area.dimensions_3D.x  # Sum all widths
		max_depth = max(max_depth, area.dimensions_3D.z)  # Find max depth
	
	# Width calculation: sum_of_widths + (count-1)*BUFFER + SIDE_MARGINS
	var plate_width = total_width + (areas.size() - 1) * AREA_BUFFER_DISTANCE + (PLATE_SIDE_MARGIN * 2.0)
	
	# Depth calculation: max_depth + FRONT_BACK_MARGINS  
	var plate_depth = max_depth + (PLATE_FRONT_BACK_MARGIN * 2.0)
	
	# Height is always constant
	var plate_height = PLATE_HEIGHT
	
	
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
	
	_conflict_areas_container = Node3D.new()
	_conflict_areas_container.name = "ConflictAreas"
	add_child(_conflict_areas_container)
	
	# Position containers (input on left, output in middle, conflict on right)
	_input_areas_container.position = Vector3(-INPUT_OUTPUT_SPACING, 0, 0)
	_output_areas_container.position = Vector3(0, 0, 0)  # Center position
	_conflict_areas_container.position = Vector3(INPUT_OUTPUT_SPACING, 0, 0)  # Right position

## Populates the plate with cortical areas based on I/O classification
func _populate_cortical_areas() -> void:
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	var conflict_areas = _get_conflict_cortical_areas()
	
	
	if input_areas.size() == 0 and output_areas.size() == 0 and conflict_areas.size() == 0:
		print("  ⚠️  No I/O areas found! Plates will have no overlying cortical areas.")
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
		
		if not existing_viz:
			# CRITICAL FIX: Create the cortical area visualization if it doesn't exist
			print("    🏗️ Creating missing visualization for input area %s" % area.cortical_ID)
			existing_viz = brain_monitor_3d._add_cortical_area(area)
			if not existing_viz:
				print("      ❌ Failed to create visualization for input area %s" % area.cortical_ID)
				continue
		
		# Check if visualization is already correctly positioned on input plate
		if existing_viz.get_parent() == _input_areas_container:
			print("    ✅ Input area %s already correctly positioned on input plate, skipping repositioning" % area.cortical_ID)
			_cortical_area_visualizations[area.cortical_ID] = existing_viz
			continue
		
		var old_parent = existing_viz.get_parent()
		
		# CRITICAL: Disconnect coordinate update signals to prevent fighting parent-child movement
		if area.coordinates_3D_updated.is_connected(existing_viz.set_new_position):
			area.coordinates_3D_updated.disconnect(existing_viz.set_new_position)
		
		# Also disconnect renderer coordinate updates
		if existing_viz._dda_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate):
			area.coordinates_3D_updated.disconnect(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate)
			
		if existing_viz._directpoints_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate):
			area.coordinates_3D_updated.disconnect(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate)
		
		# CRITICAL: Also disconnect dimension update signals to prevent position conflicts
		if existing_viz._dda_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._dda_renderer.update_dimensions):
			area.dimensions_3D_updated.disconnect(existing_viz._dda_renderer.update_dimensions)
			
		if existing_viz._directpoints_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._directpoints_renderer.update_dimensions):
			area.dimensions_3D_updated.disconnect(existing_viz._directpoints_renderer.update_dimensions)
		
		# Connect to our custom dimension update handler that preserves brain region positioning
		area.dimensions_3D_updated.connect(_on_io_cortical_area_dimensions_changed.bind(area.cortical_ID))
		
		existing_viz.get_parent().remove_child(existing_viz)
		_input_areas_container.add_child(existing_viz)
		# _scale_cortical_area_visualization(existing_viz, 0.8)  # Removed - preserve original cortical area dimensions
		_position_cortical_area_on_plate(existing_viz, i, input_areas.size(), true)  # true = is_input
		_cortical_area_visualizations[area.cortical_ID] = existing_viz
	
	# Move output area visualizations from main scene to our plate
	for i in output_areas.size():
		var area = output_areas[i]
		var existing_viz = brain_monitor_3d.get_cortical_area_visualization(area.cortical_ID)
		
		if not existing_viz:
			# CRITICAL FIX: Create the cortical area visualization if it doesn't exist
			print("    🏗️ Creating missing visualization for output area %s" % area.cortical_ID)
			existing_viz = brain_monitor_3d._add_cortical_area(area)
			if not existing_viz:
				print("      ❌ Failed to create visualization for output area %s" % area.cortical_ID)
				continue
		
		# Check if visualization is already correctly positioned on output plate
		if existing_viz.get_parent() == _output_areas_container:
			print("    ✅ Output area %s already correctly positioned on output plate, skipping repositioning" % area.cortical_ID)
			_cortical_area_visualizations[area.cortical_ID] = existing_viz
			continue
		
		var old_parent = existing_viz.get_parent()
		
		# CRITICAL: Disconnect coordinate update signals to prevent fighting parent-child movement
		if area.coordinates_3D_updated.is_connected(existing_viz.set_new_position):
			area.coordinates_3D_updated.disconnect(existing_viz.set_new_position)
		
		# Also disconnect renderer coordinate updates
		if existing_viz._dda_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate):
			area.coordinates_3D_updated.disconnect(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate)
			
		if existing_viz._directpoints_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate):
			area.coordinates_3D_updated.disconnect(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate)
		
		# CRITICAL: Also disconnect dimension update signals to prevent position conflicts
		if existing_viz._dda_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._dda_renderer.update_dimensions):
			area.dimensions_3D_updated.disconnect(existing_viz._dda_renderer.update_dimensions)
			
		if existing_viz._directpoints_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._directpoints_renderer.update_dimensions):
			area.dimensions_3D_updated.disconnect(existing_viz._directpoints_renderer.update_dimensions)
		
		# Connect to our custom dimension update handler that preserves brain region positioning
		area.dimensions_3D_updated.connect(_on_io_cortical_area_dimensions_changed.bind(area.cortical_ID))
		
		existing_viz.get_parent().remove_child(existing_viz)
		_output_areas_container.add_child(existing_viz)
		# _scale_cortical_area_visualization(existing_viz, 0.8)  # Removed - preserve original cortical area dimensions
		_position_cortical_area_on_plate(existing_viz, i, output_areas.size(), false)  # false = is_output
		_cortical_area_visualizations[area.cortical_ID] = existing_viz
	
	# Move conflict area visualizations from main scene to our conflict plate  
	for i in conflict_areas.size():
		var area = conflict_areas[i]
		var existing_viz = brain_monitor_3d.get_cortical_area_visualization(area.cortical_ID)
		
		if not existing_viz:
			# CRITICAL FIX: Create the cortical area visualization if it doesn't exist
			print("    🏗️ Creating missing visualization for conflict area %s" % area.cortical_ID)
			existing_viz = brain_monitor_3d._add_cortical_area(area)
			if not existing_viz:
				print("      ❌ Failed to create visualization for conflict area %s" % area.cortical_ID)
				continue
		
		# Check if visualization is already correctly positioned on conflict plate
		if existing_viz.get_parent() == _conflict_areas_container:
			print("    ✅ Conflict area %s already correctly positioned on conflict plate, skipping repositioning" % area.cortical_ID)
			_cortical_area_visualizations[area.cortical_ID] = existing_viz
			continue
		
		var old_parent = existing_viz.get_parent()
		
		# CRITICAL: Disconnect coordinate update signals to prevent fighting parent-child movement
		if area.coordinates_3D_updated.is_connected(existing_viz.set_new_position):
			area.coordinates_3D_updated.disconnect(existing_viz.set_new_position)
		
		# Also disconnect renderer coordinate updates
		if existing_viz._dda_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate):
			area.coordinates_3D_updated.disconnect(existing_viz._dda_renderer.update_position_with_new_FEAGI_coordinate)
			
		if existing_viz._directpoints_renderer != null and area.coordinates_3D_updated.is_connected(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate):
			area.coordinates_3D_updated.disconnect(existing_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate)
		
		# CRITICAL: Also disconnect dimension update signals to prevent position conflicts
		if existing_viz._dda_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._dda_renderer.update_dimensions):
			area.dimensions_3D_updated.disconnect(existing_viz._dda_renderer.update_dimensions)
			
		if existing_viz._directpoints_renderer != null and area.dimensions_3D_updated.is_connected(existing_viz._directpoints_renderer.update_dimensions):
			area.dimensions_3D_updated.disconnect(existing_viz._directpoints_renderer.update_dimensions)
		
		# Connect to our custom dimension update handler that preserves brain region positioning
		area.dimensions_3D_updated.connect(_on_io_cortical_area_dimensions_changed.bind(area.cortical_ID))
		
		existing_viz.get_parent().remove_child(existing_viz)
		_conflict_areas_container.add_child(existing_viz)
		# Use a special flag to indicate this is a conflict area (neither purely input nor output)  
		_position_cortical_area_on_plate(existing_viz, i, conflict_areas.size(), "conflict")  # "conflict" = special conflict type
		_cortical_area_visualizations[area.cortical_ID] = existing_viz
	
	# Adjust frame size based on content
	_adjust_frame_size(input_areas.size(), output_areas.size())
	
	# Final verification of parenting
	print("🔍 FINAL PARENTING CHECK:")
	print("  📥 Input container children: %d" % _input_areas_container.get_child_count())
	print("  📤 Output container children: %d" % _output_areas_container.get_child_count())
	print("  ⚠️  Conflict container children: %d" % _conflict_areas_container.get_child_count())
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
func _position_cortical_area_on_plate(cortical_viz: UI_BrainMonitor_CorticalArea, index: int, total_count: int, area_type) -> void:
	# Use generated coordinates instead of hardcoded positioning
	var cortical_id = cortical_viz.cortical_area.cortical_ID
	var new_position = Vector3(0, 0, 0)  # fallback
	var found_generated_coords = false
	
	# Look for cortical area in generated coordinates
	
	# Determine area type and search location
	var is_input = false
	var is_output = false 
	var is_conflict = false
	
	if area_type is bool:
		is_input = (area_type == true)
		is_output = (area_type == false)
	elif area_type is String:
		if area_type == "input":
			is_input = true
		elif area_type == "output":
			is_output = true
		elif area_type == "conflict":
			is_conflict = true
	
	# Look for this cortical area in the generated coordinates
	var areas_to_search: Array
	if is_input:
		areas_to_search = _generated_io_coordinates.inputs
	elif is_output:
		areas_to_search = _generated_io_coordinates.outputs
	elif is_conflict:
		areas_to_search = _generated_io_coordinates.conflicts
	else:
		push_error("BrainRegion3D: Invalid area_type %s for cortical area %s" % [area_type, cortical_id])
		return
	
	for area_data in areas_to_search:
		if area_data.area_id == cortical_id:
			# Convert generated absolute FEAGI coordinates to relative position within brain region
			var absolute_feagi_coords = Vector3(area_data.new_coordinates)
			var brain_region_coords = Vector3(_representing_region.coordinates_3D)
			var relative_position = absolute_feagi_coords - brain_region_coords
			new_position = Vector3(relative_position.x, relative_position.y, relative_position.z)  # Use generated Y coordinate
			found_generated_coords = true
			break
	
	if not found_generated_coords:
		push_error("BrainRegion3D: No generated coordinates found for cortical area %s - this should not happen!" % cortical_id)
		return
	
	var side_label = ""
	if is_input:
		side_label = "INPUT (left, light green)"
	elif is_output:
		side_label = "OUTPUT (middle, darker green)"
	elif is_conflict:
		side_label = "CONFLICT (right, red)"
	
	
	# Calculate position relative to the appropriate container (InputAreas, OutputAreas, or ConflictAreas)
	var container: Node3D
	if is_input:
		container = _input_areas_container
	elif is_output:
		container = _output_areas_container
	elif is_conflict:
		container = _conflict_areas_container
	
	# Convert brain region FEAGI coordinates to Godot world position (same logic as _update_position)
	var brain_region_coords = _representing_region.coordinates_3D
	var brain_region_world_pos = Vector3(brain_region_coords.x, brain_region_coords.y, -brain_region_coords.z)
	
	# Calculate desired world position: apply FEAGI→Godot transform
	# X, Y add normally; Z must be inverted so areas sit INSIDE the plate (behind the front edge)
	var desired_world_pos = brain_region_world_pos + Vector3(new_position.x, new_position.y, -new_position.z)
	
	# Container position relative to brain region (from _create_containers)
	var container_offset: Vector3
	if is_input:
		container_offset = Vector3(-INPUT_OUTPUT_SPACING, 0, 0)
	elif is_output:
		container_offset = Vector3(0, 0, 0)  # Center position
	elif is_conflict:
		container_offset = Vector3(INPUT_OUTPUT_SPACING, 0, 0)  # Right position
	
	var container_world_pos = brain_region_world_pos + container_offset
	
	# Calculate position relative to container: desired_world - container_world  
	var position_relative_to_container = desired_world_pos - container_world_pos
	
	
	# CRITICAL: Move renderers via their FEAGI positioning APIs so internal state (and animations) stay in sync
	# Compute lower-left-front FEAGI coordinate from absolute center FEAGI (area_data.new_coordinates)
	var dims_feagi: Vector3i = cortical_viz.cortical_area.dimensions_3D
	# absolute_feagi_coords is available earlier; re-derive center from brain region + relative new_position
	var center_feagi: Vector3i = Vector3i(Vector3(_representing_region.coordinates_3D) + new_position)
	var lff_feagi: Vector3i = Vector3i(
		center_feagi.x - int(dims_feagi.x / 2),
		center_feagi.y - int(dims_feagi.y / 2),
		center_feagi.z - int(dims_feagi.z / 2)
	)
	
	# Position DDA renderer (structure + labels)
	if cortical_viz._dda_renderer != null:
		cortical_viz._dda_renderer.update_position_with_new_FEAGI_coordinate(lff_feagi)
	
	# Position DirectPoints renderer (points + labels)
	if cortical_viz._directpoints_renderer != null:
		cortical_viz._directpoints_renderer.update_position_with_new_FEAGI_coordinate(lff_feagi)

	# If neural connections are currently shown (hover state), rebuild them to align pulses with new position
	if cortical_viz._is_volume_moused_over:
		if cortical_viz.has_method("_hide_neural_connections"):
			cortical_viz._hide_neural_connections()
		if cortical_viz.has_method("_show_neural_connections"):
			cortical_viz._show_neural_connections()
	
	
	# print("    📍 Positioned %s on plate %s at Z-offset %.1f" % [cortical_viz.cortical_area.cortical_ID, side_label, z_offset])  # Suppressed to reduce log overflow

## Gets RAW input cortical areas (before conflict filtering) - used internally
func _get_input_cortical_areas_raw() -> Array[AbstractCorticalArea]:
	return _get_input_cortical_areas_internal()

## Gets input cortical areas based on connection chain links or direct areas (INTERNAL - no conflict filtering)
func _get_input_cortical_areas_internal() -> Array[AbstractCorticalArea]:
	var input_areas: Array[AbstractCorticalArea] = []
	
	
	# Method 1: Check input_open_chain_links for areas that receive input
	for i in range(_representing_region.input_open_chain_links.size()):
		var link: ConnectionChainLink = _representing_region.input_open_chain_links[i]
		
		if link.destination and link.destination is AbstractCorticalArea:
			var area = link.destination as AbstractCorticalArea
			if area not in input_areas:
				input_areas.append(area)
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays) - CRITICAL FIX!
	for i in range(_representing_region.partial_mappings.size()):
		var partial_mapping = _representing_region.partial_mappings[i]
		if partial_mapping.is_region_input:
			var area = partial_mapping.internal_target_cortical_area
			if area not in input_areas:
				input_areas.append(area)
	
	# Method 3: If no chain links, fall back to checking IPU types and making educated guesses
	if _representing_region.input_open_chain_links.size() == 0:
		# Check for IPU type areas directly contained in this brain region
		for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU and area not in input_areas:
				input_areas.append(area)
		
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
	
	return input_areas

## Gets input cortical areas (FILTERED - excludes conflicts that appear in both inputs and outputs)
func _get_input_cortical_areas() -> Array[AbstractCorticalArea]:
	var raw_input_areas = _get_input_cortical_areas_internal()
	var conflict_areas = _get_conflict_cortical_areas()
	var pure_input_areas: Array[AbstractCorticalArea] = []
	
	# Filter out conflicted areas
	for area in raw_input_areas:
		var is_conflict = false
		for conflict_area in conflict_areas:
			if area.cortical_ID == conflict_area.cortical_ID:
				is_conflict = true
				break
		if not is_conflict:
			pure_input_areas.append(area)
	
	return pure_input_areas

## Gets RAW output cortical areas (before conflict filtering) - used internally
func _get_output_cortical_areas_raw() -> Array[AbstractCorticalArea]:
	return _get_output_cortical_areas_internal()

## Gets output cortical areas based on connection chain links or direct areas (INTERNAL - no conflict filtering)
func _get_output_cortical_areas_internal() -> Array[AbstractCorticalArea]:
	var output_areas: Array[AbstractCorticalArea] = []
	
	
	# Method 1: Check output_open_chain_links for areas that provide output
	for i in range(_representing_region.output_open_chain_links.size()):
		var link: ConnectionChainLink = _representing_region.output_open_chain_links[i]
		
		if link.source and link.source is AbstractCorticalArea:
			var area = link.source as AbstractCorticalArea
			if area not in output_areas:
				output_areas.append(area)
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays) - CRITICAL FIX!
	for i in range(_representing_region.partial_mappings.size()):
		var partial_mapping = _representing_region.partial_mappings[i]
		if not partial_mapping.is_region_input:  # Output mapping
			var area = partial_mapping.internal_target_cortical_area
			if area not in output_areas:
				output_areas.append(area)
	
	# Method 3: If no chain links, fall back to checking OPU types and making educated guesses
	if _representing_region.output_open_chain_links.size() == 0:
		# Check for OPU type areas directly contained in this brain region
		for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU and area not in output_areas:
				output_areas.append(area)
		
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
	
	return output_areas

## Gets output cortical areas (FILTERED - excludes conflicts that appear in both inputs and outputs)
func _get_output_cortical_areas() -> Array[AbstractCorticalArea]:
	var raw_output_areas = _get_output_cortical_areas_internal()
	var conflict_areas = _get_conflict_cortical_areas()
	var pure_output_areas: Array[AbstractCorticalArea] = []
	
	# Filter out conflicted areas
	for area in raw_output_areas:
		var is_conflict = false
		for conflict_area in conflict_areas:
			if area.cortical_ID == conflict_area.cortical_ID:
				is_conflict = true
				break
		if not is_conflict:
			pure_output_areas.append(area)
	
	return pure_output_areas

## Gets cortical areas that appear in both inputs and outputs (conflicted areas)
func _get_conflict_cortical_areas() -> Array[AbstractCorticalArea]:
	var input_areas = _get_input_cortical_areas_internal()  # Get raw inputs without conflict filtering
	var output_areas = _get_output_cortical_areas_internal()  # Get raw outputs without conflict filtering
	var conflict_areas: Array[AbstractCorticalArea] = []
	
	
	# Find areas that appear in both input and output lists
	for input_area in input_areas:
		for output_area in output_areas:
			if input_area.cortical_ID == output_area.cortical_ID:
				if input_area not in conflict_areas:
					conflict_areas.append(input_area)
	
	return conflict_areas

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
	
	if _conflict_areas_container:
		print("  ⚠️  CONFLICT AREA POSITIONS:")
		for child in _conflict_areas_container.get_children():
			var cortical_viz = child as UI_BrainMonitor_CorticalArea
			if cortical_viz:
				_log_single_cortical_area_position(cortical_viz, "CONFLICT")

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
				break
		
		# Check outputs if not found in inputs
		if not found_coords:
			for area_data in _generated_io_coordinates.outputs:
				if area_data.area_id == cortical_id:
					var new_feagi_coords = Vector3(area_data.new_coordinates)
					new_feagi_coords.z = -new_feagi_coords.z  # Flip Z for Godot
					desired_world_pos = new_feagi_coords
					found_coords = true
					break
		
		# Check conflicts if not found in inputs or outputs
		if not found_coords:
			for area_data in _generated_io_coordinates.conflicts:
				if area_data.area_id == cortical_id:
					var new_feagi_coords = Vector3(area_data.new_coordinates)
					new_feagi_coords.z = -new_feagi_coords.z  # Flip Z for Godot
					desired_world_pos = new_feagi_coords
					found_coords = true
					print("        ✅ Found as CONFLICT: %s -> world pos: %s" % [cortical_id, desired_world_pos])
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
	# Connect monitoring signals for the new area
	_connect_area_signals(area)
	_refresh_frame_contents()

func _on_cortical_area_removed(area: AbstractCorticalArea) -> void:
	print("🧠 BrainRegion3D: Cortical area removed from region, refreshing frame")
	if area.cortical_ID in _cortical_area_visualizations:
		_cortical_area_visualizations[area.cortical_ID].queue_free()
		_cortical_area_visualizations.erase(area.cortical_ID)
	_refresh_frame_contents()

## Forces a complete refresh of the brain region (public method for external calls)
func force_refresh() -> void:
	print("🔄 FORCE REFRESH: External refresh requested for region '%s'" % _representing_region.friendly_name)
	_refresh_frame_contents()

## Starts monitoring connections for changes that could affect I/O status
func _start_connection_monitoring() -> void:
	print("🔗 CONNECTION MONITORING: Starting for region '%s'" % _representing_region.friendly_name)
	# Connect to mapping update signals for all areas in this region
	for area in _representing_region.contained_cortical_areas:
		_connect_area_signals(area)
	
	# Also listen to global mapping cache updates and refresh if related to this region
	if FeagiCore and FeagiCore.feagi_local_cache and FeagiCore.feagi_local_cache.mapping_data:
		var mappings_cache := FeagiCore.feagi_local_cache.mapping_data
		if not mappings_cache.mapping_created.is_connected(_on_global_mapping_changed):
			mappings_cache.mapping_created.connect(_on_global_mapping_changed)
		if not mappings_cache.mapping_updated.is_connected(_on_global_mapping_changed):
			mappings_cache.mapping_updated.connect(_on_global_mapping_changed)

	# Listen to region-level partial mapping updates (if emitted) to trigger refresh
	if _representing_region:
		if not _representing_region.partial_mappings_inputted.is_connected(_on_region_partial_mappings_changed):
			_representing_region.partial_mappings_inputted.connect(_on_region_partial_mappings_changed)
		if not _representing_region.partial_mappings_about_to_be_removed.is_connected(_on_region_partial_mappings_changed):
			_representing_region.partial_mappings_about_to_be_removed.connect(_on_region_partial_mappings_changed)

## Connects to signals for a cortical area to monitor connection changes
func _connect_area_signals(area: AbstractCorticalArea) -> void:
	# Connect to concrete mapping structure change signals on the cortical area
	if area.has_signal("afferent_input_cortical_area_added"):
		if not area.afferent_input_cortical_area_added.is_connected(_on_area_connections_changed):
			area.afferent_input_cortical_area_added.connect(_on_area_connections_changed.bind(area))
	if area.has_signal("efferent_input_cortical_area_added"):
		if not area.efferent_input_cortical_area_added.is_connected(_on_area_connections_changed):
			area.efferent_input_cortical_area_added.connect(_on_area_connections_changed.bind(area))
	if area.has_signal("afferent_input_cortical_area_removed"):
		if not area.afferent_input_cortical_area_removed.is_connected(_on_area_connections_changed):
			area.afferent_input_cortical_area_removed.connect(_on_area_connections_changed.bind(area))
	if area.has_signal("efferent_input_cortical_area_removed"):
		if not area.efferent_input_cortical_area_removed.is_connected(_on_area_connections_changed):
			area.efferent_input_cortical_area_removed.connect(_on_area_connections_changed.bind(area))

	# Also connect to dimension changes which might affect positioning
	if not area.dimensions_3D_updated.is_connected(_on_area_dimensions_changed):
		area.dimensions_3D_updated.connect(_on_area_dimensions_changed.bind(area))
		print("  📐 Connected to dimensions_updated for area: %s" % area.cortical_ID)

## Disconnects signals previously connected for a cortical area
func _disconnect_area_signals(area: AbstractCorticalArea) -> void:
	if area == null:
		return
	# Recreate the same bound callables used during connect
	var cb_conn := _on_area_connections_changed.bind(area)
	var cb_dim := _on_area_dimensions_changed.bind(area)
	# Mapping structure change signals
	if area.has_signal("afferent_input_cortical_area_added"):
		if area.afferent_input_cortical_area_added.is_connected(cb_conn):
			area.afferent_input_cortical_area_added.disconnect(cb_conn)
	if area.has_signal("efferent_input_cortical_area_added"):
		if area.efferent_input_cortical_area_added.is_connected(cb_conn):
			area.efferent_input_cortical_area_added.disconnect(cb_conn)
	if area.has_signal("afferent_input_cortical_area_removed"):
		if area.afferent_input_cortical_area_removed.is_connected(cb_conn):
			area.afferent_input_cortical_area_removed.disconnect(cb_conn)
	if area.has_signal("efferent_input_cortical_area_removed"):
		if area.efferent_input_cortical_area_removed.is_connected(cb_conn):
			area.efferent_input_cortical_area_removed.disconnect(cb_conn)
	# Dimension change signal
	if area.dimensions_3D_updated.is_connected(cb_dim):
		area.dimensions_3D_updated.disconnect(cb_dim)


## Global mapping cache event handler (created/updated)
func _on_global_mapping_changed(mapping: InterCorticalMappingSet) -> void:
	if not _connection_monitoring_enabled:
		return
	# Only refresh if this mapping involves an area within this region
	var src := mapping.source_cortical_area
	var dst := mapping.destination_cortical_area
	if _representing_region and (src in _representing_region.contained_cortical_areas or dst in _representing_region.contained_cortical_areas):
		print("🌐 GLOBAL MAPPING CHANGE: Refreshing region '%s' due to mapping %s -> %s" % [_representing_region.friendly_name, src.cortical_ID, dst.cortical_ID])
		_check_io_status_and_refresh()


## Region-level partial mappings change handler
func _on_region_partial_mappings_changed(_param) -> void:
	if not _connection_monitoring_enabled:
		return
	print("🧭 REGION PARTIAL MAPPINGS CHANGED: Triggering refresh for region '%s'" % _representing_region.friendly_name)
	_check_io_status_and_refresh()


## Checks if I/O status has changed and refreshes if needed
func _check_io_status_and_refresh() -> void:
	print("🔍 CHECKING I/O STATUS: Analyzing current vs previous I/O configuration")
	# Force refresh - the I/O detection logic will handle determining conflicts
	force_refresh()

## Validates that all plates are properly aligned
func _validate_plate_alignment() -> void:
	if not _frame_container:
		return
		
	print("🔍 PLATE ALIGNMENT VALIDATION:")
	var input_plate = _frame_container.get_node_or_null("InputPlate")
	var output_plate = _frame_container.get_node_or_null("OutputPlate") 
	var conflict_plate = _frame_container.get_node_or_null("ConflictPlate")
	
	if input_plate:
		print("  ✅ Input Plate - Position: %s, Global: %s" % [input_plate.position, input_plate.global_position])
	if output_plate:
		print("  ✅ Output Plate - Position: %s, Global: %s" % [output_plate.position, output_plate.global_position])
	if conflict_plate:
		print("  ✅ Conflict Plate - Position: %s, Global: %s" % [conflict_plate.position, conflict_plate.global_position])
		# Check alignment
		if input_plate and output_plate and conflict_plate:
			var y_diff_input_output = abs(input_plate.position.y - output_plate.position.y)
			var y_diff_output_conflict = abs(output_plate.position.y - conflict_plate.position.y)
			if y_diff_input_output > 0.1 or y_diff_output_conflict > 0.1:
				print("  ⚠️  ALIGNMENT WARNING: Plates may not be properly aligned in Y-axis")
				print("    Input-Output Y diff: %.3f" % y_diff_input_output)
				print("    Output-Conflict Y diff: %.3f" % y_diff_output_conflict)
			else:
				print("  ✅ All plates properly aligned in Y-axis")
	else:
		print("  📝 No conflict plate (no conflicted areas)")

## Refreshes the entire frame contents
func _refresh_frame_contents() -> void:
	print("🔄 REFRESH: Starting frame content refresh for region '%s'" % _representing_region.friendly_name)
	
	# Log current partial mappings state for debugging
	print("  📊 CURRENT PARTIAL MAPPINGS:")
	print("    📊 Total partial_mappings: %d" % _representing_region.partial_mappings.size())
	for i in range(_representing_region.partial_mappings.size()):
		var mapping = _representing_region.partial_mappings[i]
		print("      🔗 Mapping %d: %s (%s)" % [i, mapping.internal_target_cortical_area.cortical_ID, "INPUT" if mapping.is_region_input else "OUTPUT"])
	
	# CRITICAL: Clean up ALL children to prevent node duplication
	_cleanup_all_children()
	
	# Get current I/O areas to determine what should be kept
	var current_input_areas = _get_input_cortical_areas()
	var current_output_areas = _get_output_cortical_areas()
	var current_conflict_areas = _get_conflict_cortical_areas()

	var current_io_ids: Array[String] = []
	
	for area in current_input_areas:
		current_io_ids.append(area.cortical_ID)
	for area in current_output_areas:
		current_io_ids.append(area.cortical_ID)
	
	# Only clear visualizations that are no longer I/O areas
	var visualizations_to_remove: Array[String] = []
	for area_id in _cortical_area_visualizations.keys():
		if area_id not in current_io_ids:
			visualizations_to_remove.append(area_id)
			print("🧹 REFRESH: Removing visualization for area %s (no longer I/O for this region)" % area_id)
	
	# Remove outdated visualizations
	for area_id in visualizations_to_remove:
		if area_id in _cortical_area_visualizations:
			_cortical_area_visualizations[area_id].queue_free()
			_cortical_area_visualizations.erase(area_id)
	
	print("🔄 REFRESH: Keeping %d existing I/O visualizations, removed %d outdated ones" % [current_io_ids.size() - visualizations_to_remove.size(), visualizations_to_remove.size()])
	
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
	
	# CRITICAL FIX: Regenerate coordinates for newly detected I/O areas
	print("🔄 REFRESH: Regenerating I/O coordinates for updated area set")
	_generated_io_coordinates = generate_io_coordinates_for_brain_region(_representing_region)
	
	# CRITICAL FIX: Recreate plates with updated sizes for new I/O area count
	print("🔄 REFRESH: Recreating plates for updated I/O area set")
	if _frame_container:
		_frame_container.queue_free()
		# Reset container references since they'll be recreated
		_input_areas_container = null
		_output_areas_container = null
		_conflict_areas_container = null
	_create_3d_plate()
	_create_containers()
	
	# Repopulate (will reuse existing I/O visualizations where possible)
	_populate_cortical_areas()
	
	# Validate plate alignment
	call_deferred("_validate_plate_alignment")
	
	# CRITICAL FIX: Update label position after all elements are in place
	call_deferred("_update_label_position_after_refresh")

## Updates the region label position to center it between the new plates after refresh
func _update_label_position_after_refresh() -> void:
	if not _region_name_label or not _representing_region:
		return
	
	# Recalculate plate sizes for current I/O areas
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	var conflict_areas = _get_conflict_cortical_areas()
	var input_plate_size = _calculate_plate_size_for_areas(input_areas, "INPUT")
	var output_plate_size = _calculate_plate_size_for_areas(output_areas, "OUTPUT")
	var conflict_plate_size = _calculate_plate_size_for_areas(conflict_areas, "CONFLICT")
	
	# Recalculate total width and center position (including conflict plate if it exists)
	var total_width = input_plate_size.x + PLATE_GAP + output_plate_size.x
	if conflict_areas.size() > 0:
		total_width += PLATE_GAP + conflict_plate_size.x  # Add conflict plate to total width
	var center_x = total_width / 2.0
	
	# Update label position: attach to MotherPlate if present
	var mother: MeshInstance3D = _frame_container.get_node_or_null("MotherPlate") as MeshInstance3D
	if mother != null:
		if _region_name_label.get_parent() != mother:
			var prev_parent = _region_name_label.get_parent()
			if prev_parent != null:
				prev_parent.remove_child(_region_name_label)
			mother.add_child(_region_name_label)
		# Place just below bezel and slightly in front of its front face
		if mother.mesh is BoxMesh:
			var bezel_front2 = (mother.mesh as BoxMesh).size.z / 2.0
			_region_name_label.position = Vector3(0.0, -(PLATE_HEIGHT / 2.0) - 0.25, -(bezel_front2 + 0.05))
		else:
			_region_name_label.position = Vector3(0.0, -(PLATE_HEIGHT / 2.0) - 0.25, -0.05)
	else:
		var front_edge_world_z = -_representing_region.coordinates_3D.z
		_region_name_label.global_position = Vector3(global_position.x, global_position.y - 0.5, front_edge_world_z - 1.0)
	
	print("🏷️ LABEL UPDATE: Repositioned region label '%s' to center between updated plates" % _representing_region.friendly_name)
	print("    📐 New plate sizes - Input: %s, Output: %s, Conflict: %s, Total width: %.1f" % [input_plate_size, output_plate_size, conflict_plate_size, total_width])
	print("    📍 New label position: %s (centered at X=%.1f)" % [_region_name_label.global_position, center_x])

## Handles hover/selection interaction
func set_hover_state(is_hovered: bool) -> void:
	# Note: Dual-plate design doesn't need hover color changes - plates already have distinct colors
	# Input plate: dark green, Output plate: dark blue
	
	region_hover_changed.emit(_representing_region, is_hovered)

## Handles double-click for diving into region
func handle_double_click() -> void:
	region_double_clicked.emit(_representing_region)
	print("🧠 BrainRegion3D: Double-clicked region '%s' - ready for dive-in navigation" % _representing_region.friendly_name)

## CRITICAL: Cleans up ALL children to prevent node duplication during refresh
func _cleanup_all_children() -> void:
	print("🧹 CLEANUP: Removing all children from region '%s' to prevent duplication" % _representing_region.friendly_name)
	var children_count = get_child_count()
	print("  📦 Removing %d children..." % children_count)
	
	# Store important nodes we want to keep
	var keep_label = _region_name_label
	
	# Remove all children
	for child in get_children():
		print("    🗑️ Removing child: %s (%s)" % [child.name, child.get_class()])
		remove_child(child)
		child.queue_free()
	
	# Reset important references
	_frame_container = null
	_input_areas_container = null
	_output_areas_container = null
	_conflict_areas_container = null
	_region_name_label = null
	_cortical_area_visualizations.clear()
	
	print("  ✅ Cleanup complete - all children removed and references reset")

## CRITICAL: Disable connection monitoring to prevent recursive refresh loops
var _connection_monitoring_enabled: bool = true
var _dimension_recalc_in_progress: bool = false

func _disable_connection_monitoring() -> void:
	_connection_monitoring_enabled = false
	print("🔇 MONITORING: Disabled connection monitoring for region '%s'" % _representing_region.friendly_name)
	# Disconnect area-level signals to avoid duplicate connections later
	if _representing_region:
		for area in _representing_region.contained_cortical_areas:
			_disconnect_area_signals(area)
	# Disconnect global mapping cache listeners
	if FeagiCore and FeagiCore.feagi_local_cache and FeagiCore.feagi_local_cache.mapping_data:
		var mappings_cache := FeagiCore.feagi_local_cache.mapping_data
		if mappings_cache.mapping_created.is_connected(_on_global_mapping_changed):
			mappings_cache.mapping_created.disconnect(_on_global_mapping_changed)
		if mappings_cache.mapping_updated.is_connected(_on_global_mapping_changed):
			mappings_cache.mapping_updated.disconnect(_on_global_mapping_changed)
	# Disconnect region-level partial mapping listeners
	if _representing_region:
		if _representing_region.partial_mappings_inputted.is_connected(_on_region_partial_mappings_changed):
			_representing_region.partial_mappings_inputted.disconnect(_on_region_partial_mappings_changed)
		if _representing_region.partial_mappings_about_to_be_removed.is_connected(_on_region_partial_mappings_changed):
			_representing_region.partial_mappings_about_to_be_removed.disconnect(_on_region_partial_mappings_changed)

func _enable_connection_monitoring() -> void:
	_connection_monitoring_enabled = true
	print("🔊 MONITORING: Enabled connection monitoring for region '%s'" % _representing_region.friendly_name)
	# Reconnect listeners now that monitoring is enabled
	_start_connection_monitoring()

## DEBUG: Prints detailed system state for troubleshooting flaky behavior
func debug_current_system_state() -> void:
	print("🔍 DEBUG STATE: Current system state for region '%s'" % _representing_region.friendly_name)
	print("  🔗 Connection monitoring enabled: %s" % _connection_monitoring_enabled)
	print("  📦 Child count: %d" % get_child_count())
	print("  🎨 Cortical visualizations count: %d" % _cortical_area_visualizations.size())
	
	# Check partial mappings
	print("  📊 PARTIAL MAPPINGS (%d total):" % _representing_region.partial_mappings.size())
	for i in range(_representing_region.partial_mappings.size()):
		var mapping = _representing_region.partial_mappings[i]
		print("    🔗 %d: %s (%s)" % [i, mapping.internal_target_cortical_area.cortical_ID, "INPUT" if mapping.is_region_input else "OUTPUT"])
	
	# Check I/O detection results
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas() 
	var conflict_areas = _get_conflict_cortical_areas()

	# Check plate existence
	print("  🏗️ PLATE STATUS:")
	if _frame_container:
		print("    ✅ Frame container exists")
		print("    🟢 Input plate: %s" % ("EXISTS" if _frame_container.has_node("InputPlate") else "MISSING"))
		print("    🟢 Output plate: %s" % ("EXISTS" if _frame_container.has_node("OutputPlate") else "MISSING"))
		print("    🔴 Conflict plate: %s" % ("EXISTS" if _frame_container.has_node("ConflictPlate") else "MISSING"))
	else:
		print("    ❌ Frame container is NULL")
		
	# Check container references
	print("  📦 CONTAINER REFERENCES:")
	print("    📥 Input container: %s" % ("EXISTS" if _input_areas_container else "NULL"))
	print("    📤 Output container: %s" % ("EXISTS" if _output_areas_container else "NULL"))
	print("    🔴 Conflict container: %s" % ("EXISTS" if _conflict_areas_container else "NULL"))

## Called when connections change for an area in this region (with monitoring control)
func _on_area_connections_changed(area: AbstractCorticalArea) -> void:
	if not _connection_monitoring_enabled:
		print("🔇 MONITORING: Ignoring connection change for %s (monitoring disabled)" % area.cortical_ID)
		return
		
	print("🔗 CONNECTION CHANGE: Area %s connections changed, checking I/O status" % area.cortical_ID)
	# Small delay to ensure connection changes are fully processed
	call_deferred("_check_io_status_and_refresh")

## Called when dimensions change for an area in this region (with monitoring control)
func _on_area_dimensions_changed(area: AbstractCorticalArea) -> void:
	if not _connection_monitoring_enabled:
		print("🔇 MONITORING: Ignoring dimension change for %s (monitoring disabled)" % area.cortical_ID)
		return
	# Debounce multiple dimension changes in a single frame
	print("📐 DIMENSION CHANGE: Area %s dimensions changed -> scheduling comprehensive plate rebuild" % area.cortical_ID)
	call_deferred("_recalculate_plates_and_positioning_after_dimension_change")
