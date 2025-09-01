extends Node
class_name UI_BrainMonitor_CorticalArea
## Class for rendering cortical areas in the Brain monitor
# NOTE: We will leave adding, removing, or changing parent region to the Brain Monitor itself, since those interactions affect multiple objects

var cortical_area: AbstractCorticalArea:
	get: return _representing_cortial_area

var renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer:
	get: return _dda_renderer

var is_volume_moused_over: bool:
	get: return _is_volume_moused_over

var _representing_cortial_area: AbstractCorticalArea
var _dda_renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer  # For translucent voxel structure
var _directpoints_renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer  # For individual neuron firing

var _is_volume_moused_over: bool
var _hovered_neuron_coordinates: Array[Vector3i] = [] # wouldnt a dictionary be faster?
var _selected_neuron_coordinates: Array[Vector3i] = [] #TODO we should clear this and the hover on dimension changes!

# Neural connection visualization
var _connection_curves: Array[Node3D] = []  # Store all connection curve nodes
var _are_connections_visible: bool = false
var _pulse_tweens: Array[Tween] = []  # Store pulse animation tweens


func setup(defined_cortical_area: AbstractCorticalArea) -> void:
	_representing_cortial_area = defined_cortical_area
	name = "CA_" + defined_cortical_area.cortical_ID
	
	# Create renderers based on cortical area type
	if (_representing_cortial_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY or 
		_representing_cortial_area.cortical_ID == "_power" or
		_representing_cortial_area.cortical_ID == "_death" or
		_should_use_png_icon(_representing_cortial_area)):
		# Memory, Power, Death, and PNG icon areas use only DirectPoints renderer (no DDA cube)
		_directpoints_renderer = UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
		add_child(_directpoints_renderer)
		_directpoints_renderer.setup(_representing_cortial_area)
		print("   🎯 Using ONLY DirectPoints renderer for: ", _representing_cortial_area.cortical_ID)
		print("   🚫 NO DDA renderer created - should have no cube!")
	else:
		# Standard areas use DDA renderer for translucent voxel structure
		_dda_renderer = _create_renderer_depending_on_cortical_area_type(_representing_cortial_area)
		add_child(_dda_renderer)
		_dda_renderer.setup(_representing_cortial_area)
		
		# Create DirectPoints renderer for individual neuron firing
		_directpoints_renderer = UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
		add_child(_directpoints_renderer)
		_directpoints_renderer.setup(_representing_cortial_area)
		print("   🎯 Using BOTH DDA and DirectPoints renderers for: ", _representing_cortial_area.cortical_ID)
	
	# setup signals to update properties automatically for renderers
	if _dda_renderer != null:
		defined_cortical_area.friendly_name_updated.connect(_dda_renderer.update_friendly_name)
		defined_cortical_area.coordinates_3D_updated.connect(_dda_renderer.update_position_with_new_FEAGI_coordinate)
		defined_cortical_area.dimensions_3D_updated.connect(_dda_renderer.update_dimensions)
	
	if _directpoints_renderer != null:
		defined_cortical_area.coordinates_3D_updated.connect(_directpoints_renderer.update_position_with_new_FEAGI_coordinate)
		defined_cortical_area.dimensions_3D_updated.connect(_directpoints_renderer.update_dimensions)
	
	# Connect legacy SVO visualization data to DDA renderer (for translucent structure)
	if _dda_renderer != null:
		defined_cortical_area.recieved_new_neuron_activation_data.connect(_dda_renderer.update_visualization_data)
	
	# Connect direct points data to DirectPoints renderer (for individual firing neurons)
	if _directpoints_renderer.has_method("_on_received_direct_neural_points"):
		defined_cortical_area.recieved_new_direct_neural_points.connect(_directpoints_renderer._on_received_direct_neural_points)
		print("🔗 CONNECTED: Type 11 (Direct Neural Points) signal for DirectPoints renderer")
	
	# Connect bulk direct points data for optimized processing
	if _directpoints_renderer.has_method("_on_received_direct_neural_points_bulk"):
		defined_cortical_area.recieved_new_direct_neural_points_bulk.connect(_directpoints_renderer._on_received_direct_neural_points_bulk)
		print("🚀 CONNECTED: Type 11 (Bulk Neural Points) signal for optimized DirectPoints rendering")
	
	print("✅ DUAL RENDERER SETUP: DDA (translucent structure) + DirectPoints (individual neurons)")

## Sets new position (in FEAGI space)
func set_new_position(new_position: Vector3i) -> void:
	if _dda_renderer != null:
		_dda_renderer.update_position_with_new_FEAGI_coordinate(new_position)
	if _directpoints_renderer != null:
		_directpoints_renderer.update_position_with_new_FEAGI_coordinate(new_position)

func set_hover_over_volume_state(is_moused_over: bool, is_global_mode: bool = false) -> void:
	print("🖱️ HOVER STATE CHANGE for ", _representing_cortial_area.cortical_ID, ": ", is_moused_over, " (global: ", is_global_mode, ")")
	
	if is_moused_over == _is_volume_moused_over:
		print("   🔄 Same hover state, skipping")
		return
	_is_volume_moused_over = is_moused_over
	if _dda_renderer != null:
		_dda_renderer.set_cortical_area_mouse_over_highlighting(is_moused_over)
	if _directpoints_renderer != null:
		_directpoints_renderer.set_cortical_area_mouse_over_highlighting(is_moused_over)
	
	# Show/hide neural connection curves on hover
	if is_moused_over:
		print("   🔗 Calling _show_neural_connections() with global mode: ", is_global_mode)
		_show_neural_connections(is_global_mode)
	else:
		print("   🔗 Calling _hide_neural_connections()")
		_hide_neural_connections()

func set_highlighted_neurons(neuron_coordinates: Array[Vector3i]) -> void:
		_hovered_neuron_coordinates = neuron_coordinates
		if _dda_renderer != null:
			_dda_renderer.set_highlighted_neurons(neuron_coordinates)
		if _directpoints_renderer != null:
			_directpoints_renderer.set_highlighted_neurons(neuron_coordinates)

func clear_hover_state_for_all_neurons() -> void:
	if len(_hovered_neuron_coordinates) != 0:
		_hovered_neuron_coordinates = []
		if _dda_renderer != null:
			_dda_renderer.set_highlighted_neurons(_hovered_neuron_coordinates)
		if _directpoints_renderer != null:
			_directpoints_renderer.set_highlighted_neurons(_hovered_neuron_coordinates)

func set_neuron_selection_state(neuron_coordinate: Vector3i, is_selected: bool) -> void:
	var index: int = _selected_neuron_coordinates.find(neuron_coordinate)
	if (index != -1 && is_selected):
		return #nothing to change
	if is_selected:
		_selected_neuron_coordinates.append(neuron_coordinate)
	else:
		_selected_neuron_coordinates.remove_at(index)
	if _dda_renderer != null:
		_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
	if _directpoints_renderer != null:
		_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)

# flips the neuron coordinate selection state, and returns the new state (if its selected now)
func toggle_neuron_selection_state(neuron_coordinate: Vector3i) -> bool:
	var index: int = _selected_neuron_coordinates.find(neuron_coordinate)
	var is_selected: bool
	if index == -1:
		_selected_neuron_coordinates.append(neuron_coordinate)
		is_selected = true
	else:
		_selected_neuron_coordinates.remove_at(index)
		is_selected = false
	if _dda_renderer != null:
		_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
	if _directpoints_renderer != null:
		_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)
	return is_selected

func clear_all_neuron_selection_states() -> void:
	if len(_selected_neuron_coordinates) != 0:
		_selected_neuron_coordinates =  []
		if _dda_renderer != null:
			_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
		if _directpoints_renderer != null:
			_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)

func get_neuron_selection_states() -> Array[Vector3i]:
	return _selected_neuron_coordinates

func _create_renderer_depending_on_cortical_area_type(defined_cortical_area: AbstractCorticalArea) -> UI_BrainMonitor_AbstractCorticalAreaRenderer:
	print("🎮 BRAIN VISUALIZER RENDERER SELECTION:")
	print("   📊 Cortical Area: ", defined_cortical_area.cortical_ID)
	print("   🔍 Cortical Type: ", defined_cortical_area.cortical_type)
	
	# Special cases: Memory and Power cortical areas use DirectPoints rendering
	if defined_cortical_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		print("   🔮 USING: Memory Sphere Renderer")
		print("   📝 Expected data format: Type 11 (Direct Points)")
		print("   🎯 Features: Sphere mesh, memory-specific visualization")
		return UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
	elif defined_cortical_area.cortical_ID == "_power":
		print("   ⚡ USING: Power Cone Renderer")
		print("   📝 Expected data format: Type 11 (Direct Points)")
		print("   🎯 Features: Cone mesh, power-specific visualization with firing animation")
		return UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
	else:
		# Use DDA renderer for all other cortical area types
		print("   🔄 USING: DDA Renderer (Sparse Voxel Octree)")
		print("   📝 Expected data format: Type 10 (NEURON_FLAT/SVO)")
		print("   🎯 Features: Translucent voxel structure, shader-based rendering")
		return UI_BrainMonitor_DDACorticalAreaRenderer.new()

## Show 3D curves connecting this cortical area to all its destinations
func _show_neural_connections(is_global_mode: bool = false) -> void:
	if _are_connections_visible:
		print("   🔄 Connections already visible, skipping")
		return  # Already showing connections
	
	print("🔗 SHOWING neural connections for: ", _representing_cortial_area.cortical_ID)
	print("   🔍 Cortical area type: ", _representing_cortial_area.cortical_type)
	if _representing_cortial_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		print("   🔮 This is a MEMORY cortical area - checking connections...")
	
	# Clear any existing pulse tweens
	_pulse_tweens.clear()
	
	# Debug: Check if we have the cortical area object
	if _representing_cortial_area == null:
		print("   ❌ ERROR: _representing_cortial_area is null!")
		return
	
	# Get all efferent (outgoing) connections from this cortical area
	var efferent_mappings = _representing_cortial_area.efferent_mappings
	print("   🔍 DEBUG: efferent_mappings type: ", typeof(efferent_mappings))
	print("   🔍 DEBUG: efferent_mappings size: ", efferent_mappings.size())
	
	if _representing_cortial_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		print("   🔮 MEMORY AREA DEBUG:")
		print("     📊 Efferent mappings: ", efferent_mappings.size())
		if efferent_mappings.size() > 0:
			print("     🎯 Memory area HAS outgoing connections!")
			for dest_area in efferent_mappings.keys():
				print("       → ", dest_area.cortical_ID)
		else:
			print("     ❌ Memory area has NO outgoing connections")
	
	if efferent_mappings.is_empty():
		print("   ❌ No efferent connections found for: ", _representing_cortial_area.cortical_ID)
		return
	
	print("   📊 Found ", efferent_mappings.size(), " efferent connections")
	
	# Get the center position of this cortical area
	var source_position = _get_cortical_area_center_position()
	print("   🎯 Source position: ", source_position)
	
	if source_position == Vector3.ZERO:
		print("   ❌ ERROR: Could not get source position!")
		return
	
	# Create curves to all destination cortical areas (OUTGOING)
	var curves_created = 0
	for destination_area: AbstractCorticalArea in efferent_mappings.keys():
		print("   🎯 Processing OUTGOING to: ", destination_area.cortical_ID)
		var destination_position = _get_cortical_area_center_position_for_area(destination_area)
		print("   📍 Destination position: ", destination_position)
		
		if destination_position != Vector3.ZERO:  # Valid position found
			var mapping_set: InterCorticalMappingSet = efferent_mappings[destination_area]
			var curve_node = _create_connection_curve(source_position, destination_position, destination_area.cortical_ID, mapping_set, is_global_mode)
			_connection_curves.append(curve_node)
			add_child(curve_node)
			curves_created += 1
			print("   ✅ Created OUTGOING curve to: ", destination_area.cortical_ID)
		else:
			print("   ⚠️ Skipped outgoing connection to ", destination_area.cortical_ID, " - invalid position")
	
	# Get all afferent (incoming) connections to this cortical area
	var afferent_mappings = _representing_cortial_area.afferent_mappings
	print("   🔍 DEBUG: afferent_mappings size: ", afferent_mappings.size())
	
	if not afferent_mappings.is_empty():
		print("   📊 Found ", afferent_mappings.size(), " afferent (incoming) connections")
		
		# Create curves from all source cortical areas (INCOMING)
		for source_area: AbstractCorticalArea in afferent_mappings.keys():
			print("   🎯 Processing INCOMING from: ", source_area.cortical_ID)
			var source_area_position = _get_cortical_area_center_position_for_area(source_area)
			print("   📍 Source position: ", source_area_position)
			
			if source_area_position != Vector3.ZERO:  # Valid position found
				var mapping_set: InterCorticalMappingSet = afferent_mappings[source_area]
				var curve_node = _create_connection_curve(source_area_position, source_position, source_area.cortical_ID, mapping_set, is_global_mode)
				_connection_curves.append(curve_node)
				add_child(curve_node)
				curves_created += 1
				print("   ✅ Created INCOMING curve from: ", source_area.cortical_ID)
			else:
				print("   ⚠️ Skipped incoming connection from ", source_area.cortical_ID, " - invalid position")
	else:
		print("   ❌ No afferent (incoming) connections found")
	
	# Get all recursive (self) connections within this cortical area
	var recursive_mappings = _representing_cortial_area.recursive_mappings
	print("   🔍 DEBUG: recursive_mappings size: ", recursive_mappings.size())
	
	if not recursive_mappings.is_empty():
		print("   📊 Found ", recursive_mappings.size(), " recursive (self) connections")
		
		# Create looping curves for recursive connections
		for recursive_area: AbstractCorticalArea in recursive_mappings.keys():
			print("   🎯 Processing RECURSIVE connection in: ", recursive_area.cortical_ID)
			
			# Create a self-looping curve
			var mapping_set: InterCorticalMappingSet = recursive_mappings[recursive_area]
			var loop_node = _create_recursive_loop(source_position, recursive_area.cortical_ID, mapping_set, is_global_mode)
			_connection_curves.append(loop_node)
			add_child(loop_node)
			curves_created += 1
			print("   ✅ Created RECURSIVE loop for: ", recursive_area.cortical_ID)
	else:
		print("   ❌ No recursive (self) connections found")
	
	_are_connections_visible = true
	var total_connections = efferent_mappings.size() + afferent_mappings.size() + recursive_mappings.size()
	print("   🎯 Total curves created: ", curves_created, " out of ", total_connections, " connections (", efferent_mappings.size(), " outgoing + ", afferent_mappings.size(), " incoming + ", recursive_mappings.size(), " recursive)")

## Hide all neural connection curves
func _hide_neural_connections() -> void:
	if not _are_connections_visible:
		return  # Already hidden
	
	print("🔗 HIDING neural connections for: ", _representing_cortial_area.cortical_ID)
	
	# Stop all pulse animations
	for tween in _pulse_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_pulse_tweens.clear()
	
	# Remove all curve nodes
	for curve_node in _connection_curves:
		if curve_node != null:
			curve_node.queue_free()
	
	_connection_curves.clear()
	_are_connections_visible = false
	print("   ✅ All connection curves and pulse animations removed")

## Get the center position of this cortical area in world space
func _get_cortical_area_center_position() -> Vector3:
	print("     🔍 Getting position for: ", _representing_cortial_area.cortical_ID)
	print("     🔍 _dda_renderer: ", _dda_renderer != null)
	print("     🔍 _directpoints_renderer: ", _directpoints_renderer != null)
	
	if _representing_cortial_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		print("     🔮 MEMORY AREA position retrieval...")
	
	# Use the renderer's static body position as the center
	if _dda_renderer != null and _dda_renderer._static_body != null:
		var pos = _dda_renderer._static_body.global_position
		print("     ✅ DDA renderer position: ", pos)
		return pos
	elif _directpoints_renderer != null and _directpoints_renderer._static_body != null:
		var pos = _directpoints_renderer._static_body.global_position
		print("     ✅ DirectPoints renderer position: ", pos)
		return pos
	else:
		print("     ❌ No renderer or static body available for: ", _representing_cortial_area.cortical_ID)
		if _dda_renderer != null:
			print("     🔍 DDA renderer exists but _static_body is: ", _dda_renderer._static_body)
		if _directpoints_renderer != null:
			print("     🔍 DirectPoints renderer exists but _static_body is: ", _directpoints_renderer._static_body)
		return Vector3.ZERO

## Get the center position of another cortical area by finding its renderer in the scene
func _get_cortical_area_center_position_for_area(area: AbstractCorticalArea) -> Vector3:
	# 🚨 FIX: Use main 3D scene's cortical area registry instead of parent searching
	# This fixes connection visualization for I/O areas moved to brain region containers
	
	# Find the main 3D scene by traversing up the tree
	var current_node = self
	var main_3d_scene: UI_BrainMonitor_3DScene = null
	
	while current_node != null:
		current_node = current_node.get_parent()
		if current_node is UI_BrainMonitor_3DScene:
			main_3d_scene = current_node as UI_BrainMonitor_3DScene
			break
	
	if main_3d_scene == null:
		print("   ⚠️ Could not find main 3D scene for cortical area lookup")
		return Vector3.ZERO
	
	# Use the 3D scene's cortical area registry to find the target
	var target_visualization = main_3d_scene.get_cortical_area_visualization(area.cortical_ID)
	
	if target_visualization == null:
		print("   ⚠️ Could not find cortical area visualization for: ", area.cortical_ID)
		return Vector3.ZERO
	
	# Get position from the target's renderer  
	return target_visualization._get_cortical_area_center_position()

## Create a 3D curve connecting two points
func _create_connection_curve(start_pos: Vector3, end_pos: Vector3, connection_id: StringName, mapping_set: InterCorticalMappingSet, is_global_mode: bool = false) -> Node3D:
	var is_inhibitory = _is_mapping_set_inhibitory(mapping_set)
	var is_plastic = _is_mapping_set_plastic(mapping_set)  # Back to original logic
	var connection_type = "INHIBITORY" if is_inhibitory else "EXCITATORY"
	var plasticity_type = "PLASTIC" if is_plastic else "NON-PLASTIC"
	print("     🎨 Creating 3D curve ", connection_type, " ", plasticity_type, " to ", connection_id, ": ", start_pos, " → ", end_pos)
	
	# Create a container for the curve segments
	var connection_node = Node3D.new()
	var type_prefix = "INH_" if is_inhibitory else "EXC_"
	var plastic_prefix = "PLA_" if is_plastic else "STD_" 
	connection_node.name = type_prefix + plastic_prefix + connection_id
	
	# Calculate curve parameters
	var direction = (end_pos - start_pos)
	var distance = direction.length()
	var mid_point = (start_pos + end_pos) / 2.0
	
	# Create an upward arc - arc height based on distance
	var arc_height = distance * 0.4  # 40% of distance for nice arc
	var control_point = mid_point + Vector3(0, arc_height, 0)
	
	# For plastic connections, add wobble effect by modifying control point and segments
	var is_wobbly = is_plastic
	
	print("     🌈 Arc height: ", arc_height, " Control point: ", control_point)
	
	# Create curve segments - more segments = smoother curve  
	var num_segments = 20 if is_wobbly else 12  # Even more segments for dramatic wobbly curves
	var segment_material = _create_curve_material(is_inhibitory, is_global_mode)
	
	# Create animated material for plastic connections with breathing effect
	if is_plastic:
		segment_material = _create_plastic_animated_material(is_inhibitory, is_global_mode)
	
	# Store curve points for pulse animation
	var curve_points: Array[Vector3] = []
	
	for i in range(num_segments):
		var t1 = float(i) / float(num_segments)
		var t2 = float(i + 1) / float(num_segments)
		
		# Calculate points on quadratic Bezier curve
		var point1 = _quadratic_bezier(start_pos, control_point, end_pos, t1)
		var point2 = _quadratic_bezier(start_pos, control_point, end_pos, t2)
		
		# Store base points for animation (without wobble initially)
		if i == 0:
			curve_points.append(point1)
		curve_points.append(point2)
		
		# Create cylinder segment between these two points
		var segment = _create_curve_segment(point1, point2, i, segment_material)
		connection_node.add_child(segment)
		
		# Add continuous wobble animation for plastic connections
		if is_plastic:
			_add_continuous_wobble_animation(segment, point1, point2, t1, t2, start_pos, control_point, end_pos)
			_add_plastic_thickness_animation(segment, t1)
	
	# Create pulse animation along this curve
	_create_pulse_animation(connection_node, curve_points, connection_id, is_inhibitory)
	
	print("     ✨ Created beautiful 3D curve with ", num_segments, " segments and pulse animation")
	return connection_node

## Calculate point on quadratic Bezier curve
func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

## Create a single segment of the curve
func _create_curve_segment(start_pos: Vector3, end_pos: Vector3, segment_index: int, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "CurveSegment_" + str(segment_index)
	
	# Calculate segment properties
	var direction = (end_pos - start_pos)
	var segment_length = direction.length()
	var center_pos = (start_pos + end_pos) / 2.0
	
	# Create cylinder mesh for this segment
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.15  # Thinner for elegant curve
	cylinder_mesh.bottom_radius = 0.15
	cylinder_mesh.height = segment_length
	cylinder_mesh.radial_segments = 6
	cylinder_mesh.rings = 1
	
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.position = center_pos
	
	# Rotate segment to align with direction
	if direction.length() > 0.001:
		var normalized_direction = direction.normalized()
		var up_vector = Vector3.UP
		if abs(normalized_direction.dot(Vector3.UP)) > 0.9:
			up_vector = Vector3.FORWARD
		
		var right_vector = up_vector.cross(normalized_direction).normalized()
		var corrected_up = normalized_direction.cross(right_vector).normalized()
		var basis = Basis(right_vector, normalized_direction, corrected_up)
		mesh_instance.basis = basis
	
	mesh_instance.material_override = material
	return mesh_instance

## Create material for curve segments based on inhibitory/excitatory properties
func _create_curve_material(is_inhibitory: bool = false, is_global_mode: bool = false) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	if is_global_mode:
		# Global mode - Gray color for all connections
		material.albedo_color = Color(0.7, 0.7, 0.7, 0.8)  # Light gray
		material.emission_color = Color(0.5, 0.5, 0.5)     # Gray emission
		print("     ⚪ Using GRAY material for GLOBAL mode connection")
	elif is_inhibitory:
		# Inhibitory connections - Red color
		material.albedo_color = Color(1.0, 0.2, 0.2, 0.9)  # Bright red
		material.emission_color = Color(0.8, 0.1, 0.1)
		print("     🔴 Using RED material for INHIBITORY connection")
	else:
		# Excitatory (non-inhibitory) connections - Green color
		material.albedo_color = Color(0.2, 1.0, 0.3, 0.9)  # Bright green
		material.emission_color = Color(0.1, 0.8, 0.2)
		print("     🟢 Using GREEN material for EXCITATORY connection")
	
	material.emission_enabled = true
	material.emission_energy = 2.0
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Create pulse animation along the curve
func _create_pulse_animation(curve_node: Node3D, curve_points: Array[Vector3], connection_id: StringName, is_inhibitory: bool = false) -> void:
	var connection_type = "INHIBITORY" if is_inhibitory else "EXCITATORY"
	print("     ⚡ Creating pulse animation for ", connection_type, " connection: ", connection_id)
	
	# Create multiple pulse spheres for continuous animation
	var num_pulses = 3  # Multiple pulses traveling at once
	
	for pulse_index in range(num_pulses):
		# Create a glowing pulse sphere
		var pulse_sphere = MeshInstance3D.new()
		pulse_sphere.name = "Pulse_" + str(pulse_index)
		
		# Create sphere mesh
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.3
		sphere_mesh.height = 0.6
		sphere_mesh.radial_segments = 8
		sphere_mesh.rings = 4
		pulse_sphere.mesh = sphere_mesh
		
		# Create bright pulsing material with different colors based on connection type
		var pulse_material = StandardMaterial3D.new()
		if is_inhibitory:
			# Inhibitory pulses - Bright red/orange
			pulse_material.albedo_color = Color(1.0, 0.5, 0.3, 0.8)  # Bright red-orange
			pulse_material.emission_color = Color(1.0, 0.3, 0.1)
			print("       🔴 Creating RED pulse for INHIBITORY connection")
		else:
			# Excitatory pulses - Bright lime/green
			pulse_material.albedo_color = Color(0.3, 1.0, 0.3, 0.8)  # Bright lime
			pulse_material.emission_color = Color(0.2, 1.0, 0.2)
			print("       🟢 Creating GREEN pulse for EXCITATORY connection")
		
		pulse_material.emission_enabled = true
		pulse_material.emission_energy = 4.0
		pulse_material.flags_unshaded = true
		pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pulse_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive for glow
		pulse_sphere.material_override = pulse_material
		
		# Start pulse at beginning of curve
		pulse_sphere.position = curve_points[0]
		curve_node.add_child(pulse_sphere)
		
		# Create animation tween
		var pulse_tween = create_tween()
		pulse_tween.set_loops()  # Infinite loop
		_pulse_tweens.append(pulse_tween)
		
		# Stagger the pulses so they don't all start together
		var delay = pulse_index * 0.5  # 0.5 second delay between pulses
		var travel_time = 2.0  # Time to travel the full curve
		
		# Add initial delay for staggering
		if delay > 0:
			pulse_tween.tween_interval(delay)
		
		# Animate the pulse along the curve points
		pulse_tween.tween_method(
			func(progress: float):
				var point_index = int(progress * (curve_points.size() - 1))
				var local_progress = (progress * (curve_points.size() - 1)) - point_index
				
				# Interpolate between current and next point
				if point_index < curve_points.size() - 1:
					var current_point = curve_points[point_index]
					var next_point = curve_points[point_index + 1]
					pulse_sphere.position = current_point.lerp(next_point, local_progress)
				else:
					pulse_sphere.position = curve_points[-1]  # End point
				
				# Pulse the glow intensity
				var glow_intensity = 3.0 + sin(Time.get_ticks_msec() / 100.0) * 1.5
				pulse_material.emission_energy = glow_intensity,
			0.0,
			1.0,
			travel_time
		)
		
		# Add a brief pause at the end before restarting
		pulse_tween.tween_interval(0.3)
	
	print("     ✨ Created ", num_pulses, " animated pulses")

## Create a recursive (self-looping) connection
func _create_recursive_loop(center_pos: Vector3, area_id: StringName, mapping_set: InterCorticalMappingSet, is_global_mode: bool = false) -> Node3D:
	var is_inhibitory = _is_mapping_set_inhibitory(mapping_set)
	var is_plastic = _is_mapping_set_plastic(mapping_set)  # Back to original logic
	var connection_type = "INHIBITORY" if is_inhibitory else "EXCITATORY"
	var plasticity_type = "PLASTIC" if is_plastic else "NON-PLASTIC"
	print("     🔄 Creating recursive loop ", connection_type, " ", plasticity_type, " for: ", area_id, " at position: ", center_pos)
	
	# Create a container for the loop
	var loop_node = Node3D.new()
	var type_prefix = "INH_RECURS_" if is_inhibitory else "EXC_RECURS_"
	var plastic_prefix = "PLA_" if is_plastic else "STD_"
	loop_node.name = type_prefix + plastic_prefix + area_id
	
	# Create a circular loop around the cortical area
	var loop_radius = 3.0  # Radius of the loop around the area
	var loop_height = 2.0  # Height above the area center
	var num_segments = 16  # More segments for smooth circle
	
	# Calculate loop points in a circle
	var loop_points: Array[Vector3] = []
	for i in range(num_segments + 1):  # +1 to close the loop
		var angle = (i / float(num_segments)) * TAU
		var loop_point = center_pos + Vector3(
			cos(angle) * loop_radius,
			loop_height,
			sin(angle) * loop_radius
		)
		loop_points.append(loop_point)
	
	# Create loop segments with wobble effect for plastic connections
	var loop_material = _create_recursive_material(is_inhibitory, is_global_mode)
	
	# Use enhanced plastic material for plastic recursive connections
	if is_plastic:
		loop_material = _create_plastic_animated_material(is_inhibitory, is_global_mode)
	for i in range(num_segments):
		var point1 = loop_points[i]
		var point2 = loop_points[i + 1]
		
		var segment = _create_curve_segment(point1, point2, i, loop_material)
		loop_node.add_child(segment)
		
		# Add continuous wobble and thickness animation for plastic recursive connections
		if is_plastic:
			var t1 = float(i) / float(num_segments)
			var t2 = float(i + 1) / float(num_segments)
			# For recursive loops, create a simplified wobble around the base loop position
			_add_continuous_loop_wobble_animation(segment, point1, point2, t1)
			_add_plastic_thickness_animation(segment, t1)
	
	# Create recursive pulse animation
	_create_recursive_pulse_animation(loop_node, loop_points, area_id, is_inhibitory)
	
	print("     ✨ Created recursive loop with ", num_segments, " segments")
	return loop_node

## Create material for recursive connections based on inhibitory/excitatory properties
func _create_recursive_material(is_inhibitory: bool = false, is_global_mode: bool = false) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	if is_global_mode:
		# Global mode - Gray color for recursive connections
		material.albedo_color = Color(0.7, 0.7, 0.7, 0.8)  # Light gray
		material.emission_color = Color(0.5, 0.5, 0.5)     # Gray emission
		print("     ⚪ Using GRAY material for GLOBAL mode RECURSIVE connection")
	elif is_inhibitory:
		# Inhibitory recursive connections - Dark red/maroon
		material.albedo_color = Color(0.8, 0.2, 0.2, 0.9)  # Dark red
		material.emission_color = Color(0.6, 0.1, 0.1)
		print("     🟤 Using DARK RED material for INHIBITORY RECURSIVE connection")
	else:
		# Excitatory recursive connections - Purple/Magenta color (distinct from regular green)
		material.albedo_color = Color(1.0, 0.3, 1.0, 0.9)  # Bright magenta
		material.emission_color = Color(0.8, 0.2, 0.8)
		print("     🟣 Using MAGENTA material for EXCITATORY RECURSIVE connection")
	
	material.emission_enabled = true
	material.emission_energy = 2.5
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Create pulse animation for recursive loops
func _create_recursive_pulse_animation(loop_node: Node3D, loop_points: Array[Vector3], area_id: StringName, is_inhibitory: bool = false) -> void:
	var connection_type = "INHIBITORY" if is_inhibitory else "EXCITATORY"
	print("     ⚡ Creating ", connection_type, " recursive pulse animation for: ", area_id)
	
	# Create multiple pulses traveling around the loop
	var num_pulses = 2  # Fewer pulses for cleaner loop animation
	
	for pulse_index in range(num_pulses):
		# Create a glowing pulse sphere
		var pulse_sphere = MeshInstance3D.new()
		pulse_sphere.name = "RecursivePulse_" + str(pulse_index)
		
		# Create sphere mesh (slightly smaller for recursive)
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.25  # Smaller than regular pulses
		sphere_mesh.height = 0.5
		sphere_mesh.radial_segments = 8
		sphere_mesh.rings = 4
		pulse_sphere.mesh = sphere_mesh
		
		# Create bright pulsing material based on connection type
		var pulse_material = StandardMaterial3D.new()
		pulse_material.emission_enabled = true
		pulse_material.emission_energy = 4.0
		pulse_material.flags_unshaded = true
		pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pulse_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		
		if is_inhibitory:
			# Inhibitory recursive - Dark red pulse
			pulse_material.albedo_color = Color(0.8, 0.3, 0.3, 0.8)  # Dark red
			pulse_material.emission_color = Color(0.8, 0.2, 0.2)
			print("       🟤 Creating DARK RED pulse for INHIBITORY RECURSIVE connection")
		else:
			# Excitatory recursive - Bright purple pulse
			pulse_material.albedo_color = Color(1.0, 0.5, 1.0, 0.8)  # Bright purple
			pulse_material.emission_color = Color(1.0, 0.3, 1.0)
			print("       🟣 Creating PURPLE pulse for EXCITATORY RECURSIVE connection")
		
		pulse_sphere.material_override = pulse_material
		
		# Start pulse at beginning of loop
		pulse_sphere.position = loop_points[0]
		loop_node.add_child(pulse_sphere)
		
		# Create animation tween
		var pulse_tween = create_tween()
		pulse_tween.set_loops()  # Infinite loop
		_pulse_tweens.append(pulse_tween)
		
		# Stagger the pulses
		var delay = pulse_index * 1.0  # 1 second delay between recursive pulses
		var travel_time = 3.0  # Slower travel for recursive loops
		
		# Add initial delay for staggering
		if delay > 0:
			pulse_tween.tween_interval(delay)
		
		# Animate the pulse around the loop
		pulse_tween.tween_method(
			func(progress: float):
				var point_index = int(progress * (loop_points.size() - 2))  # -2 because last point = first point
				var local_progress = (progress * (loop_points.size() - 2)) - point_index
				
				# Interpolate between current and next point
				if point_index < loop_points.size() - 1:
					var current_point = loop_points[point_index]
					var next_point = loop_points[point_index + 1]
					pulse_sphere.position = current_point.lerp(next_point, local_progress)
				else:
					pulse_sphere.position = loop_points[0]  # Back to start
				
				# Pulse the glow intensity
				var glow_intensity = 3.0 + sin(Time.get_ticks_msec() / 80.0) * 1.5
				pulse_material.emission_energy = glow_intensity,
			0.0,
			1.0,
			travel_time
		)
		
		# Brief pause before restarting
		pulse_tween.tween_interval(0.2)
	
	print("     ✨ Created ", num_pulses, " recursive animated pulses")

## Check if a cortical area should use PNG icon rendering
func _should_use_png_icon(area: AbstractCorticalArea) -> bool:
	# Add more cortical area IDs here that should use PNG icons
	var png_icon_areas = ["_death", "_health", "_energy", "_status"]  # Expandable list
	return area.cortical_ID in png_icon_areas

## Helper function to determine if a mapping set contains inhibitory connections
func _is_mapping_set_inhibitory(mapping_set: InterCorticalMappingSet) -> bool:
	"""Check if the mapping set contains any inhibitory connections (negative PSC multiplier)"""
	if mapping_set == null or mapping_set.mappings.is_empty():
		return false
	
	# Check all mappings in the set
	for mapping in mapping_set.mappings:
		if mapping.post_synaptic_current_multiplier < 0:
			return true  # At least one inhibitory connection found
	
	return false  # All connections are excitatory

## Helper function to determine if a mapping set contains plastic connections
func _is_mapping_set_plastic(mapping_set: InterCorticalMappingSet) -> bool:
	"""Check if the mapping set contains any plastic connections"""
	if mapping_set == null or mapping_set.mappings.is_empty():
		return false
	
	# Check all mappings in the set
	for mapping in mapping_set.mappings:
		if mapping.is_plastic:
			return true  # At least one plastic connection found
	
	return false  # All connections are non-plastic

## Helper function to determine if MAJORITY of mappings in a set are plastic (for connection-wide effects)
func _is_mapping_set_majority_plastic(mapping_set: InterCorticalMappingSet) -> bool:
	"""Check if the majority of mappings in the set are plastic - use this for visual effects"""
	if mapping_set == null or mapping_set.mappings.is_empty():
		return false
	
	var plastic_count = 0
	var total_count = mapping_set.mappings.size()
	
	for mapping in mapping_set.mappings:
		if mapping.is_plastic:
			plastic_count += 1
	
	return plastic_count > (total_count / 2)  # More than 50% are plastic

## Add dramatic wobble effect to a point for plastic connections
func _add_wobble_to_point(point: Vector3, t: float) -> Vector3:
	"""Add a dramatic, highly visible wobble effect to connection points for plastic connections"""
	var time = Time.get_ticks_msec() / 1000.0  # Current time in seconds
	var wobble_strength = 1.2  # Much stronger wobble - 4x stronger than before
	var wobble_frequency = 1.5  # Slightly slower for more dramatic effect
	
	# Create multiple layered sine waves for very organic, snake-like movement
	var primary_wobble_x = sin(time * wobble_frequency + t * PI * 2) * wobble_strength
	var primary_wobble_y = cos(time * wobble_frequency * 1.3 + t * PI * 1.5) * wobble_strength * 0.8
	var primary_wobble_z = sin(time * wobble_frequency * 0.8 + t * PI * 2.5) * wobble_strength
	
	# Add secondary higher-frequency ripples for more complexity
	var ripple_strength = wobble_strength * 0.3
	var ripple_frequency = wobble_frequency * 3.5
	var secondary_wobble_x = sin(time * ripple_frequency + t * PI * 4) * ripple_strength
	var secondary_wobble_y = cos(time * ripple_frequency * 1.7 + t * PI * 3) * ripple_strength
	var secondary_wobble_z = sin(time * ripple_frequency * 1.2 + t * PI * 5) * ripple_strength
	
	# Combine primary and secondary wobbles
	var total_wobble = Vector3(
		primary_wobble_x + secondary_wobble_x,
		primary_wobble_y + secondary_wobble_y,
		primary_wobble_z + secondary_wobble_z
	)
	
	return point + total_wobble

## Create animated material for plastic connections with pulsing effects
func _create_plastic_animated_material(is_inhibitory: bool = false, is_global_mode: bool = false) -> StandardMaterial3D:
	"""Create a dynamic, pulsing material for plastic connections with enhanced visual effects"""
	var material = StandardMaterial3D.new()
	
	if is_global_mode:
		# Global mode - Gray color for all connections
		material.albedo_color = Color(0.7, 0.7, 0.7, 0.8)
		material.emission_color = Color(0.5, 0.5, 0.5)
		print("     ⚪ Using GRAY PLASTIC material for GLOBAL mode connection")
	elif is_inhibitory:
		# Inhibitory plastic connections - Enhanced red with stronger base emission
		material.albedo_color = Color(1.0, 0.3, 0.3, 0.95)  # More opaque for visibility
		material.emission_color = Color(1.0, 0.2, 0.2)  # Brighter emission
		print("     🔴⚡ Using ANIMATED RED material for INHIBITORY PLASTIC connection")
	else:
		# Excitatory plastic connections - Enhanced green with stronger base emission  
		material.albedo_color = Color(0.3, 1.0, 0.4, 0.95)  # More opaque for visibility
		material.emission_color = Color(0.2, 1.0, 0.3)  # Brighter emission
		print("     🟢⚡ Using ANIMATED GREEN material for EXCITATORY PLASTIC connection")
	
	material.emission_enabled = true
	material.emission_energy = 3.0  # Higher base emission for plastic connections
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.metallic = 0.3  # Add some metallic sheen for plastic connections
	material.roughness = 0.4
	
	return material

## Add dynamic thickness animation to plastic connection segments
func _add_plastic_thickness_animation(segment: MeshInstance3D, t_position: float) -> void:
	"""Add breathing/pulsing thickness animation to plastic connection segments"""
	if not segment or not segment.mesh:
		return
	
	# Create a tween for continuous thickness animation
	var thickness_tween = create_tween()
	thickness_tween.set_loops()  # Infinite animation
	
	# Store reference to the original cylinder mesh
	var cylinder_mesh = segment.mesh as CylinderMesh
	if not cylinder_mesh:
		return
	
	var base_radius = cylinder_mesh.top_radius
	var thickness_variation = 0.08  # More subtle thickness variation (8% instead of 15%)
	var breathing_speed = 2.5 + (t_position * 0.5)  # Speed varies along curve
	
	print("       🫁 Adding breathing thickness animation to plastic segment at t=", t_position)
	
	# Animate thickness with breathing effect
	thickness_tween.tween_method(
		func(scale_factor: float):
			# Safety checks - ensure objects still exist
			if not segment or not is_instance_valid(segment):
				thickness_tween.kill()  # Stop animation if segment is destroyed
				return
			
			if not cylinder_mesh or not is_instance_valid(cylinder_mesh):
				thickness_tween.kill()  # Stop animation if mesh is destroyed
				return
			
			var time_offset = t_position * PI * 2  # Phase shift based on position
			var breathing = sin(Time.get_ticks_msec() / 1000.0 * breathing_speed + time_offset) * thickness_variation
			var new_radius = base_radius * (1.0 + breathing)
			
			# Apply thickness changes safely
			cylinder_mesh.top_radius = new_radius
			cylinder_mesh.bottom_radius = new_radius
			
			# Also pulse the material emission energy with null safety
			if segment.material_override != null:
				var material = segment.material_override as StandardMaterial3D
				if material != null:
					var emission_pulse = 1.0 + (sin(Time.get_ticks_msec() / 1000.0 * breathing_speed * 1.5 + time_offset) * 0.2)  # More subtle pulse - reduced from 0.4 to 0.2
					material.emission_energy = 3.0 * emission_pulse,
		0.0,
		1.0,
		breathing_speed
	)

## Add continuous wobble animation to plastic connection segments
func _add_continuous_wobble_animation(segment: MeshInstance3D, base_point1: Vector3, base_point2: Vector3, t1: float, t2: float, curve_start: Vector3, curve_control: Vector3, curve_end: Vector3) -> void:
	"""Create continuous wobble animation for plastic connection segments"""
	if not segment:
		return
	
	print("       🌊 Adding continuous wobble animation to plastic segment at t1=", t1, " t2=", t2)
	
	# Create a tween for continuous position animation
	var wobble_tween = create_tween()
	wobble_tween.set_loops()  # Infinite animation
	
	# Store base positions and curve info
	var segment_center = (base_point1 + base_point2) / 2.0
	var segment_direction = (base_point2 - base_point1).normalized()
	var segment_length = base_point1.distance_to(base_point2)
	
	# Animate the segment position with wobble
	wobble_tween.tween_method(
		func(animation_time: float):
			# Safety check
			if not segment or not is_instance_valid(segment):
				wobble_tween.kill()
				return
			
			# Calculate subtle wobble offset
			var wobble_strength = 0.4  # Much more subtle - reduced from 1.2
			var wobble_frequency = 1.2  # Slightly slower
			var time_offset = (t1 + t2) * 0.5 * PI * 2  # Phase shift based on position along curve
			
			# Create gentle layered wobble movement
			var primary_wobble_x = sin(animation_time * wobble_frequency + time_offset) * wobble_strength
			var primary_wobble_y = cos(animation_time * wobble_frequency * 1.3 + time_offset * 1.5) * wobble_strength * 0.7
			var primary_wobble_z = sin(animation_time * wobble_frequency * 0.8 + time_offset * 2.5) * wobble_strength
			
			# Add very gentle secondary ripples
			var ripple_strength = wobble_strength * 0.2  # Reduced from 0.3
			var ripple_frequency = wobble_frequency * 2.5  # Reduced from 3.5
			var secondary_wobble_x = sin(animation_time * ripple_frequency + time_offset * 4) * ripple_strength
			var secondary_wobble_y = cos(animation_time * ripple_frequency * 1.7 + time_offset * 3) * ripple_strength
			var secondary_wobble_z = sin(animation_time * ripple_frequency * 1.2 + time_offset * 5) * ripple_strength
			
			var total_wobble = Vector3(
				primary_wobble_x + secondary_wobble_x,
				primary_wobble_y + secondary_wobble_y,
				primary_wobble_z + secondary_wobble_z
			)
			
			# Apply wobble to segment center position
			var new_center = segment_center + total_wobble
			
			# Recalculate the segment endpoints with wobble
			var half_direction = segment_direction * (segment_length / 2.0)
			var new_point1 = new_center - half_direction + total_wobble * 0.3  # Vary endpoints slightly
			var new_point2 = new_center + half_direction + total_wobble * 0.7
			
			# Update segment position and orientation
			segment.position = (new_point1 + new_point2) / 2.0
			
			# Update segment rotation to face new direction
			var new_direction = (new_point2 - new_point1).normalized()
			if new_direction.length() > 0.001:
				var up_vector = Vector3.UP
				if abs(new_direction.dot(Vector3.UP)) > 0.9:
					up_vector = Vector3.FORWARD
				var right_vector = up_vector.cross(new_direction).normalized()
				var corrected_up = new_direction.cross(right_vector).normalized()
				segment.basis = Basis(right_vector, new_direction, corrected_up),
		0.0,
		100.0,  # Long animation time for smooth looping
		5.0     # 5 second loop cycle
	)

## Add continuous wobble animation to plastic recursive loop segments
func _add_continuous_loop_wobble_animation(segment: MeshInstance3D, base_point1: Vector3, base_point2: Vector3, t_position: float) -> void:
	"""Create continuous wobble animation for plastic recursive loop segments"""
	if not segment:
		return
	
	print("       🔄 Adding continuous loop wobble animation to plastic segment at t=", t_position)
	
	# Create a tween for continuous position animation
	var loop_wobble_tween = create_tween()
	loop_wobble_tween.set_loops()  # Infinite animation
	
	# Store base positions
	var segment_center = (base_point1 + base_point2) / 2.0
	var segment_direction = (base_point2 - base_point1).normalized()
	var segment_length = base_point1.distance_to(base_point2)
	
	# Animate the segment position with wobble (simpler for loops)
	loop_wobble_tween.tween_method(
		func(animation_time: float):
			# Safety check
			if not segment or not is_instance_valid(segment):
				loop_wobble_tween.kill()
				return
			
			# Calculate subtle wobble offset (simpler for recursive loops)
			var wobble_strength = 0.3  # Much more subtle - reduced from 0.8
			var wobble_frequency = 1.4  # Slightly slower
			var time_offset = t_position * PI * 2
			
			var wobble_x = sin(animation_time * wobble_frequency + time_offset) * wobble_strength
			var wobble_y = cos(animation_time * wobble_frequency * 1.2 + time_offset * 1.3) * wobble_strength * 0.6
			var wobble_z = sin(animation_time * wobble_frequency * 0.9 + time_offset * 1.8) * wobble_strength
			
			var total_wobble = Vector3(wobble_x, wobble_y, wobble_z)
			
			# Apply wobble to segment position
			segment.position = segment_center + total_wobble,
		0.0,
		100.0,  # Long animation time for smooth looping
		4.0     # 4 second loop cycle for recursive connections
	)
