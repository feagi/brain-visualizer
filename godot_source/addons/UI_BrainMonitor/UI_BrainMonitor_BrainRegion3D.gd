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

## Setup the 3D brain region visualization
func setup(brain_region: BrainRegion) -> void:
	_representing_region = brain_region
	name = "BrainRegion3D_" + brain_region.region_ID
	
	# Create frame structure
	_create_3d_frame()
	_create_containers()
	
	# Populate with cortical areas
	_populate_cortical_areas()
	
	# Connect to region signals for dynamic updates
	_representing_region.cortical_area_added_to_region.connect(_on_cortical_area_added)
	_representing_region.cortical_area_removed_from_region.connect(_on_cortical_area_removed)
	_representing_region.coordinates_3D_updated.connect(_update_position)
	_representing_region.friendly_name_updated.connect(_update_frame_label)
	
	# Set initial position using FEAGI coordinates
	_update_position(_representing_region.coordinates_3D)
	print("🧠 BrainRegion3D: Initial setup for region '%s' at FEAGI coordinates %v" % 
		[_representing_region.friendly_name, _representing_region.coordinates_3D])

## Creates the 3D frame structure as a simple wireframe cube
func _create_3d_frame() -> void:
	# Create single wireframe cube
	_frame_container = MeshInstance3D.new()
	_frame_container.name = "WireframeCube"
	add_child(_frame_container)
	
	# Create custom wireframe mesh with explicit line topology
	var base_size = Vector3(10.0, 6.0, 4.0)
	_frame_container.mesh = _create_wireframe_cube_mesh(base_size)
	
	# Create red line material
	_frame_material = StandardMaterial3D.new()
	_frame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_frame_material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)  # Red color
	_frame_material.flags_unshaded = true
	_frame_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frame_material.no_depth_test = false
	_frame_material.flags_do_not_receive_shadows = true
	_frame_material.flags_disable_ambient_light = true
	
	_frame_container.material_override = _frame_material
	
	print("🔴 WireframeCube: Created red wireframe lines for region '%s'" % _representing_region.friendly_name)
	
	# Create collision for interaction (invisible)
	_frame_collision = StaticBody3D.new()
	_frame_collision.name = "FrameCollision"
	add_child(_frame_collision)
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = base_size
	collision_shape.shape = box_shape
	_frame_collision.add_child(collision_shape)

## Creates a custom wireframe cube mesh using line topology
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

## Populates the frame with cortical areas based on I/O classification
func _populate_cortical_areas() -> void:
	var input_areas = _get_input_cortical_areas()
	var output_areas = _get_output_cortical_areas()
	
	print("🧠 BrainRegion3D: Populating region '%s' with %d input areas, %d output areas" % 
		[_representing_region.friendly_name, input_areas.size(), output_areas.size()])
	
	# Create input area visualizations
	for i in input_areas.size():
		var area = input_areas[i]
		var cortical_viz = _create_cortical_area_visualization(area)
		_input_areas_container.add_child(cortical_viz)
		_position_cortical_area_in_container(cortical_viz, i, input_areas.size())
		_cortical_area_visualizations[area.cortical_ID] = cortical_viz
	
	# Create output area visualizations
	for i in output_areas.size():
		var area = output_areas[i]
		var cortical_viz = _create_cortical_area_visualization(area)
		_output_areas_container.add_child(cortical_viz)
		_position_cortical_area_in_container(cortical_viz, i, output_areas.size())
		_cortical_area_visualizations[area.cortical_ID] = cortical_viz
	
	# Adjust frame size based on content
	_adjust_frame_size(input_areas.size(), output_areas.size())

## Creates a cortical area visualization for the frame
func _create_cortical_area_visualization(area: AbstractCorticalArea) -> UI_BrainMonitor_CorticalArea:
	var cortical_viz = UI_BrainMonitor_CorticalArea.new()
	cortical_viz.setup(area)
	
	# Scale down for frame representation (flush at region Z level)
	var scale_factor = 0.7  # Smaller than normal representation
	cortical_viz.scale = Vector3(scale_factor, scale_factor, scale_factor)
	
	return cortical_viz

## Positions a cortical area within its container (input or output)
func _position_cortical_area_in_container(cortical_viz: UI_BrainMonitor_CorticalArea, index: int, total_count: int) -> void:
	# Arrange vertically within the container
	var y_offset = (index - (total_count - 1) / 2.0) * CORTICAL_AREA_SPACING
	cortical_viz.position = Vector3(0, y_offset, 0)  # Z=0 to keep flush

## Gets input cortical areas based on connection chain links
func _get_input_cortical_areas() -> Array[AbstractCorticalArea]:
	var input_areas: Array[AbstractCorticalArea] = []
	
	# Check input_open_chain_links for areas that receive input
	for link: ConnectionChainLink in _representing_region.input_open_chain_links:
		if link.destination and link.destination is AbstractCorticalArea:
			var area = link.destination as AbstractCorticalArea
			if area in _representing_region.contained_cortical_areas and area not in input_areas:
				input_areas.append(area)
	
	# Also check for IPU type areas directly contained
	for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
		if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU and area not in input_areas:
			input_areas.append(area)
	
	print("🔍 Found %d input areas in region '%s'" % [input_areas.size(), _representing_region.friendly_name])
	return input_areas

## Gets output cortical areas based on connection chain links
func _get_output_cortical_areas() -> Array[AbstractCorticalArea]:
	var output_areas: Array[AbstractCorticalArea] = []
	
	# Check output_open_chain_links for areas that provide output
	for link: ConnectionChainLink in _representing_region.output_open_chain_links:
		if link.source and link.source is AbstractCorticalArea:
			var area = link.source as AbstractCorticalArea
			if area in _representing_region.contained_cortical_areas and area not in output_areas:
				output_areas.append(area)
	
	# Also check for OPU type areas directly contained
	for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
		if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU and area not in output_areas:
			output_areas.append(area)
	
	print("🔍 Found %d output areas in region '%s'" % [output_areas.size(), _representing_region.friendly_name])
	return output_areas

## Adjusts frame size based on contained cortical areas
func _adjust_frame_size(input_count: int, output_count: int) -> void:
	var max_count = max(input_count, output_count)
	var required_height = max(3.0, max_count * CORTICAL_AREA_SPACING + FRAME_PADDING.y)
	var required_width = INPUT_OUTPUT_SPACING * 2 + FRAME_PADDING.x * 2
	var required_depth = FRAME_PADDING.z * 2
	
	var new_size = Vector3(required_width, required_height, required_depth)
	
	# Update wireframe cube size
	_update_wireframe_size(new_size)
	
	# Update collision shape
	if _frame_collision.get_child(0).shape is BoxShape3D:
		(_frame_collision.get_child(0).shape as BoxShape3D).size = new_size
	
	# Update position since frame size affects center offset calculation
	_update_position(_representing_region.coordinates_3D)

## Updates the wireframe cube to new size
func _update_wireframe_size(new_size: Vector3) -> void:
	# Recreate the wireframe mesh with new size
	_frame_container.mesh = _create_wireframe_cube_mesh(new_size)

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
