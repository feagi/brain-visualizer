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
			var curve_node = _create_connection_curve(source_position, destination_position, destination_area.cortical_ID, false, is_global_mode)
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
				var curve_node = _create_connection_curve(source_area_position, source_position, source_area.cortical_ID, true, is_global_mode)
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
			var loop_node = _create_recursive_loop(source_position, recursive_area.cortical_ID, is_global_mode)
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
	# Find the cortical area renderer in the parent scene
	var parent_scene = get_parent()
	if parent_scene == null:
		return Vector3.ZERO
	
	# Look for the cortical area node by name pattern
	var target_node_name = "CA_" + area.cortical_ID
	var target_node = parent_scene.get_node_or_null(target_node_name)
	
	if target_node == null:
		print("   ⚠️ Could not find target cortical area node: ", target_node_name)
		return Vector3.ZERO
	
	# Get position from the target's renderer
	var target_cortical_area = target_node as UI_BrainMonitor_CorticalArea
	if target_cortical_area != null:
		return target_cortical_area._get_cortical_area_center_position()
	
	return Vector3.ZERO

## Create a 3D curve connecting two points
func _create_connection_curve(start_pos: Vector3, end_pos: Vector3, connection_id: StringName, is_incoming: bool = false, is_global_mode: bool = false) -> Node3D:
	var direction_text = "OUTGOING to" if not is_incoming else "INCOMING from"
	print("     🎨 Creating 3D curve ", direction_text, " ", connection_id, ": ", start_pos, " → ", end_pos)
	
	# Create a container for the curve segments
	var connection_node = Node3D.new()
	var prefix = "OUT_to_" if not is_incoming else "IN_from_"
	connection_node.name = prefix + connection_id
	
	# Calculate curve parameters
	var direction = (end_pos - start_pos)
	var distance = direction.length()
	var mid_point = (start_pos + end_pos) / 2.0
	
	# Create an upward arc - arc height based on distance
	var arc_height = distance * 0.4  # 40% of distance for nice arc
	var control_point = mid_point + Vector3(0, arc_height, 0)
	
	print("     🌈 Arc height: ", arc_height, " Control point: ", control_point)
	
	# Create curve segments - more segments = smoother curve
	var num_segments = 12  # Good balance between smoothness and performance
	var segment_material = _create_curve_material(is_incoming, is_global_mode)
	
	# Store curve points for pulse animation
	var curve_points: Array[Vector3] = []
	
	for i in range(num_segments):
		var t1 = float(i) / float(num_segments)
		var t2 = float(i + 1) / float(num_segments)
		
		# Calculate points on quadratic Bezier curve
		var point1 = _quadratic_bezier(start_pos, control_point, end_pos, t1)
		var point2 = _quadratic_bezier(start_pos, control_point, end_pos, t2)
		
		# Store points for animation
		if i == 0:
			curve_points.append(point1)
		curve_points.append(point2)
		
		# Create cylinder segment between these two points
		var segment = _create_curve_segment(point1, point2, i, segment_material)
		connection_node.add_child(segment)
	
	# Create pulse animation along this curve
	_create_pulse_animation(connection_node, curve_points, connection_id, is_incoming)
	
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

## Create material for curve segments
func _create_curve_material(is_incoming: bool = false, is_global_mode: bool = false) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	if is_global_mode:
		# Global mode - Gray color for all connections
		material.albedo_color = Color(0.7, 0.7, 0.7, 0.8)  # Light gray
		material.emission_color = Color(0.5, 0.5, 0.5)     # Gray emission
		print("     ⚪ Using GRAY material for GLOBAL mode connection")
	elif is_incoming:
		# Incoming connections - Green/Lime color
		material.albedo_color = Color(0.2, 1.0, 0.3, 0.9)  # Bright green
		material.emission_color = Color(0.1, 0.8, 0.2)
		print("     🟢 Using GREEN material for INCOMING connection")
	else:
		# Outgoing connections - Cyan/Blue color  
		material.albedo_color = Color(0.2, 0.8, 1.0, 0.9)  # Beautiful cyan
		material.emission_color = Color(0.1, 0.6, 1.0)
		print("     🔵 Using CYAN material for OUTGOING connection")
	
	material.emission_enabled = true
	material.emission_energy = 2.0
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Create pulse animation along the curve
func _create_pulse_animation(curve_node: Node3D, curve_points: Array[Vector3], connection_id: StringName, is_incoming: bool = false) -> void:
	var direction_text = "to" if not is_incoming else "from"
	print("     ⚡ Creating pulse animation for connection ", direction_text, ": ", connection_id)
	
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
		
		# Create bright pulsing material with different colors for direction
		var pulse_material = StandardMaterial3D.new()
		if is_incoming:
			# Incoming pulses - Bright lime/green
			pulse_material.albedo_color = Color(0.3, 1.0, 0.3, 0.8)  # Bright lime
			pulse_material.emission_color = Color(0.2, 1.0, 0.2)
			print("       🟢 Creating GREEN pulse for INCOMING connection")
		else:
			# Outgoing pulses - Bright yellow/orange
			pulse_material.albedo_color = Color(1.0, 1.0, 0.3, 0.8)  # Bright yellow
			pulse_material.emission_color = Color(1.0, 0.8, 0.0)
			print("       🟡 Creating YELLOW pulse for OUTGOING connection")
		
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
func _create_recursive_loop(center_pos: Vector3, area_id: StringName, is_global_mode: bool = false) -> Node3D:
	print("     🔄 Creating recursive loop for: ", area_id, " at position: ", center_pos)
	
	# Create a container for the loop
	var loop_node = Node3D.new()
	loop_node.name = "RECURSIVE_" + area_id
	
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
	
	# Create loop segments
	var loop_material = _create_recursive_material(is_global_mode)
	for i in range(num_segments):
		var point1 = loop_points[i]
		var point2 = loop_points[i + 1]
		var segment = _create_curve_segment(point1, point2, i, loop_material)
		loop_node.add_child(segment)
	
	# Create recursive pulse animation
	_create_recursive_pulse_animation(loop_node, loop_points, area_id)
	
	print("     ✨ Created recursive loop with ", num_segments, " segments")
	return loop_node

## Create material for recursive connections
func _create_recursive_material(is_global_mode: bool = false) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	if is_global_mode:
		# Global mode - Gray color for recursive connections
		material.albedo_color = Color(0.7, 0.7, 0.7, 0.8)  # Light gray
		material.emission_color = Color(0.5, 0.5, 0.5)     # Gray emission
		print("     ⚪ Using GRAY material for GLOBAL mode RECURSIVE connection")
	else:
		# Recursive connections - Purple/Magenta color
		material.albedo_color = Color(1.0, 0.3, 1.0, 0.9)  # Bright magenta
		material.emission_color = Color(0.8, 0.2, 0.8)
		print("     🟣 Using MAGENTA material for RECURSIVE connection")
	
	material.emission_enabled = true
	material.emission_energy = 2.5
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Create pulse animation for recursive loops
func _create_recursive_pulse_animation(loop_node: Node3D, loop_points: Array[Vector3], area_id: StringName) -> void:
	print("     ⚡ Creating recursive pulse animation for: ", area_id)
	
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
		
		# Create bright purple pulsing material
		var pulse_material = StandardMaterial3D.new()
		pulse_material.albedo_color = Color(1.0, 0.5, 1.0, 0.8)  # Bright purple
		pulse_material.emission_enabled = true
		pulse_material.emission_color = Color(1.0, 0.3, 1.0)
		pulse_material.emission_energy = 4.0
		pulse_material.flags_unshaded = true
		pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pulse_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pulse_sphere.material_override = pulse_material
		
		print("       🟣 Creating PURPLE pulse for RECURSIVE connection")
		
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
