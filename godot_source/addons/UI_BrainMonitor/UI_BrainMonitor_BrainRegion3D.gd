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

var representing_region: BrainRegion:
	get: return _representing_region

var _representing_region: BrainRegion
var _frame_container: MeshInstance3D
var _frame_collision: StaticBody3D
var _input_areas_container: Node3D
var _output_areas_container: Node3D
var _cortical_area_visualizations: Dictionary[StringName, UI_BrainMonitor_CorticalArea] = {}
var _frame_material: StandardMaterial3D

## Logs dimensions of all I/O cortical areas for plate sizing calculations
func _log_io_area_dimensions(brain_region: BrainRegion) -> void:
	var input_areas = _get_input_cortical_areas_for_logging(brain_region)
	var output_areas = _get_output_cortical_areas_for_logging(brain_region)
	
	print("    📥 INPUT cortical areas and dimensions:")
	for area in input_areas:
		print("      🔵 %s: dimensions %s, coordinates %s" % [area.cortical_ID, area.dimensions_3D, area.coordinates_3D])
	
	print("    📤 OUTPUT cortical areas and dimensions:")  
	for area in output_areas:
		print("      🔴 %s: dimensions %s, coordinates %s" % [area.cortical_ID, area.dimensions_3D, area.coordinates_3D])
	
	print("    📊 Total I/O areas: %d inputs + %d outputs = %d areas" % [input_areas.size(), output_areas.size(), input_areas.size() + output_areas.size()])

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
	
	_representing_region = brain_region
	name = "BrainRegion3D_" + brain_region.region_ID
	
	# Create frame structure
	print("  🔨 Creating 3D plate...")
	_create_3d_plate()
	print("  📦 Creating containers...")
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
	_update_position(_representing_region.coordinates_3D)
	print("🏁 BrainRegion3D Setup completed for region: %s" % _representing_region.friendly_name)

## Creates the 3D plate structure underneath I/O cortical areas
func _create_3d_plate() -> void:
	# Calculate plate size based on I/O cortical areas
	var input_areas = _get_input_cortical_areas_for_logging(_representing_region)
	var output_areas = _get_output_cortical_areas_for_logging(_representing_region)
	var plate_size = _calculate_plate_size(input_areas, output_areas)
	
	print("  📐 Calculated plate size: %s" % plate_size)
	print("  📍 Brain region coordinates: %s" % _representing_region.coordinates_3D)
	
	# Create the plate mesh
	_frame_container = MeshInstance3D.new()
	_frame_container.name = "BrainRegionPlate"
	add_child(_frame_container)
	
	# Create a plane mesh in XZ axis
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(plate_size.x, plate_size.z)
	plane_mesh.orientation = PlaneMesh.FACE_Y  # Facing up (XZ plane)
	_frame_container.mesh = plane_mesh
	
	# Create red semi-transparent material for the plate
	_frame_material = StandardMaterial3D.new()
	_frame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_frame_material.albedo_color = Color(1.0, 0.2, 0.2, 0.6)  # Semi-transparent red
	_frame_material.flags_unshaded = true
	_frame_material.flags_transparent = true
	_frame_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frame_material.no_depth_test = false
	_frame_material.flags_do_not_receive_shadows = true
	_frame_material.flags_disable_ambient_light = true
	
	_frame_container.material_override = _frame_material
	
	print("🔴 BrainRegionPlate: Created red XZ plate (size: %s) for region '%s'" % [Vector2(plate_size.x, plate_size.z), _representing_region.friendly_name])
	
	# Position plate underneath cortical areas (negative Y offset)
	_frame_container.position.y = -1.0  # Sit 1 unit below the cortical areas
	
	# Create collision for interaction
	_frame_collision = StaticBody3D.new()
	_frame_collision.name = "PlateCollision"
	add_child(_frame_collision)
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(plate_size.x, 0.2, plate_size.z)  # Thin collision box
	collision_shape.shape = box_shape
	collision_shape.position.y = -1.0  # Match plate position
	_frame_collision.add_child(collision_shape)

## Calculates the appropriate plate size based on I/O cortical areas
func _calculate_plate_size(input_areas: Array[AbstractCorticalArea], output_areas: Array[AbstractCorticalArea]) -> Vector3:
	var all_areas: Array[AbstractCorticalArea] = []
	all_areas.append_array(input_areas)
	all_areas.append_array(output_areas)
	
	if all_areas.size() == 0:
		print("  ⚠️  No I/O areas found, using default plate size")
		return Vector3(8.0, 0.0, 8.0)  # Default size, Y is ignored for plate
	
	# Calculate bounding box of all I/O areas
	var min_bounds = Vector3(INF, 0, INF)
	var max_bounds = Vector3(-INF, 0, -INF)
	
	for area in all_areas:
		var area_coord = Vector3(area.coordinates_3D)
		var area_size = Vector3(area.dimensions_3D)
		
		# Calculate area's bounding box
		var area_min = area_coord
		var area_max = area_coord + area_size
		
		# Update global bounds (only X and Z, ignore Y)
		min_bounds.x = min(min_bounds.x, area_min.x)
		min_bounds.z = min(min_bounds.z, area_min.z)
		max_bounds.x = max(max_bounds.x, area_max.x)
		max_bounds.z = max(max_bounds.z, area_max.z)
		
		print("      📦 Area %s: coord %s + size %s = bounds (%s to %s)" % [area.cortical_ID, area_coord, area_size, area_min, area_max])
	
	# Calculate plate size with padding
	var padding = 2.0  # Add padding around areas
	var plate_width = max_bounds.x - min_bounds.x + padding * 2
	var plate_depth = max_bounds.z - min_bounds.z + padding * 2
	
	# Ensure minimum size
	plate_width = max(plate_width, 4.0)
	plate_depth = max(plate_depth, 4.0)
	
	print("  🔢 Bounds: X(%.1f to %.1f) Z(%.1f to %.1f)" % [min_bounds.x, max_bounds.x, min_bounds.z, max_bounds.z])
	print("  📐 Plate dimensions: %.1f x %.1f (with %.1f padding)" % [plate_width, plate_depth, padding])
	
	return Vector3(plate_width, 0.0, plate_depth)

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
			existing_viz.get_parent().remove_child(existing_viz)
			_input_areas_container.add_child(existing_viz)
			_scale_cortical_area_visualization(existing_viz, 0.8)  # Slightly smaller for plate display
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
			existing_viz.get_parent().remove_child(existing_viz)
			_output_areas_container.add_child(existing_viz)
			_scale_cortical_area_visualization(existing_viz, 0.8)  # Slightly smaller for plate display
			_position_cortical_area_on_plate(existing_viz, i, output_areas.size(), false)  # false = is_output
			_cortical_area_visualizations[area.cortical_ID] = existing_viz
		else:
			print("    ❌ Could not find existing visualization for output area %s" % area.cortical_ID)
	
	# Adjust frame size based on content
	_adjust_frame_size(input_areas.size(), output_areas.size())

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
	
	print("    📏 Scaled cortical area %s renderer bodies to %s" % [cortical_viz.cortical_area.cortical_ID, scale_factor])

## Positions a cortical area on the plate (inputs on left, outputs on right)
func _position_cortical_area_on_plate(cortical_viz: UI_BrainMonitor_CorticalArea, index: int, total_count: int, is_input: bool) -> void:
	# Calculate position on the plate surface
	# Y=0 to sit directly on the plate surface
	var y_position = 0.0
	var z_offset = (index - (total_count - 1) / 2.0) * CORTICAL_AREA_SPACING  # Spread along Z axis
	var new_position = Vector3(0, y_position, z_offset)
	
	var side_label = "LEFT (input)" if is_input else "RIGHT (output)"
	
	# Position the DDA renderer's static body if it exists
	if cortical_viz._dda_renderer != null and cortical_viz._dda_renderer._static_body != null:
		cortical_viz._dda_renderer._static_body.position = new_position
		# Also position the label if it exists
		if cortical_viz._dda_renderer._friendly_name_label != null:
			cortical_viz._dda_renderer._friendly_name_label.position = new_position + Vector3(0, 1.0, 0)  # Label above cortical area
	
	# Position the DirectPoints renderer's static body if it exists  
	if cortical_viz._directpoints_renderer != null and cortical_viz._directpoints_renderer._static_body != null:
		cortical_viz._directpoints_renderer._static_body.position = new_position
		# Also position the label if it exists
		if cortical_viz._directpoints_renderer._friendly_name_label != null:
			cortical_viz._directpoints_renderer._friendly_name_label.position = new_position + Vector3(0, 1.0, 0)  # Label above cortical area
	
	print("    📍 Positioned %s on plate %s at Z-offset %.1f" % [cortical_viz.cortical_area.cortical_ID, side_label, z_offset])

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
	
	# Method 2: If no chain links, fall back to checking IPU types and making educated guesses
	if _representing_region.input_open_chain_links.size() == 0:
		print("  ⚠️  No input chain links found. Using fallback detection methods...")
		
		# Check for IPU type areas directly contained in this brain region
		print("  🔍 Checking directly contained cortical areas for IPU types...")
		for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
			print("    📦 Contained area: %s (type: %s)" % [area.cortical_ID, area.type_as_string])
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU and area not in input_areas:
				input_areas.append(area)
				print("      ✅ Added IPU input area: %s" % area.cortical_ID)
		
		# If still no areas and we have exactly 2 areas, use naming heuristics
		if input_areas.size() == 0 and _representing_region.contained_cortical_areas.size() == 2:
			print("  💡 Fallback: Using naming heuristics for 2-area region...")
			for area in _representing_region.contained_cortical_areas:
				var area_id = area.cortical_ID.to_lower()
				# Look for common input patterns in names
				if "rig" in area_id or "right" in area_id or "input" in area_id or "in" in area_id or "inp" in area_id:
					input_areas.append(area)
					print("      🎯 Selected as input (name heuristic): %s" % area.cortical_ID)
					break
			
			# If no naming match found, default to first area
			if input_areas.size() == 0:
				input_areas.append(_representing_region.contained_cortical_areas[0])
				print("      🎯 Selected as input (default first): %s" % _representing_region.contained_cortical_areas[0].cortical_ID)
	
	print("🔍 Total input areas found for '%s': %d" % [_representing_region.friendly_name, input_areas.size()])
	return input_areas

## Gets output cortical areas based on connection chain links or direct areas
func _get_output_cortical_areas() -> Array[AbstractCorticalArea]:
	var output_areas: Array[AbstractCorticalArea] = []
	
	print("🔍 Analyzing output areas for region '%s':" % _representing_region.friendly_name)
	print("  📋 output_open_chain_links count: %d" % _representing_region.output_open_chain_links.size())
	
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
	
	# Method 2: If no chain links, fall back to checking OPU types and making educated guesses
	if _representing_region.output_open_chain_links.size() == 0:
		print("  ⚠️  No output chain links found. Using fallback detection methods...")
		
		# Check for OPU type areas directly contained in this brain region
		print("  🔍 Checking directly contained cortical areas for OPU types...")
		for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
			print("    📦 Contained area: %s (type: %s)" % [area.cortical_ID, area.type_as_string])
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU and area not in output_areas:
				output_areas.append(area)
				print("      ✅ Added OPU output area: %s" % area.cortical_ID)
		
		# If still no areas and we have exactly 2 areas, use naming heuristics
		if output_areas.size() == 0 and _representing_region.contained_cortical_areas.size() == 2:
			print("  💡 Fallback: Using naming heuristics for 2-area region...")
			for area in _representing_region.contained_cortical_areas:
				var area_id = area.cortical_ID.to_lower()
				# Look for common output patterns in names (c__lef should match "lef")
				if "lef" in area_id or "left" in area_id or "output" in area_id or "out" in area_id:
					output_areas.append(area)
					print("      🎯 Selected as output (name heuristic): %s" % area.cortical_ID)
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
	
	# Update collision shape
	if _frame_collision.get_child(0).shape is BoxShape3D:
		(_frame_collision.get_child(0).shape as BoxShape3D).size = new_size
	
	# Update position since frame size affects center offset calculation
	_update_position(_representing_region.coordinates_3D)

## Updates the plate size (DEPRECATED - plates auto-size based on I/O areas)
func _update_wireframe_size(new_size: Vector3) -> void:
	# This method is deprecated - plates are sized automatically based on I/O cortical areas
	# Keeping method for compatibility but no longer recreating wireframe mesh
	print("  ⚠️  _update_wireframe_size() called but plates auto-size based on I/O areas")

## Updates position based on brain region coordinates
func _update_position(new_coordinates: Vector3i) -> void:
	# Convert FEAGI coordinates to Godot 3D space (following same convention as cortical areas)
	# FEAGI uses lower-front-left corner as origin, Godot uses center
	# Z-axis needs to be flipped for proper orientation
	
	var feagi_pos = new_coordinates
	feagi_pos.z = -feagi_pos.z  # Flip Z direction to match Godot coordinate system
	
	# For brain regions, we use the frame size as "dimensions" for offset calculation
	var frame_size = Vector3(10.0, 6.0, 4.0)  # Default frame size
	if _frame_collision and _frame_collision.get_child_count() > 0:
		var collision_shape = _frame_collision.get_child(0).shape
		if collision_shape is BoxShape3D:
			frame_size = (collision_shape as BoxShape3D).size
	
	# Calculate center offset (FEAGI lower-front-left to Godot center)
	var center_offset = frame_size / 2.0
	center_offset.z = -center_offset.z  # Flip Z offset to match coordinate system
	
	position = Vector3(feagi_pos) + center_offset
	
	print("🧠 BrainRegion3D: Positioned region '%s' at FEAGI coords %v -> Godot position %v" % 
		[_representing_region.friendly_name, new_coordinates, position])

## Updates frame label/appearance when region name changes
func _update_frame_label(new_name: StringName) -> void:
	# Could add text label to frame in future
	name = "BrainRegion3D_" + _representing_region.region_ID + "_" + str(new_name)

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
	
	# Repopulate
	_populate_cortical_areas()

## Handles hover/selection interaction
func set_hover_state(is_hovered: bool) -> void:
	if is_hovered:
		_frame_material.albedo_color = Color(1.0, 0.5, 0.0, 1.0)  # Bright orange/red when hovered
	else:
		_frame_material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)  # Solid red normally
	
	region_hover_changed.emit(_representing_region, is_hovered)

## Handles double-click for diving into region
func handle_double_click() -> void:
	region_double_clicked.emit(_representing_region)
	print("🧠 BrainRegion3D: Double-clicked region '%s' - ready for dive-in navigation" % _representing_region.friendly_name)
