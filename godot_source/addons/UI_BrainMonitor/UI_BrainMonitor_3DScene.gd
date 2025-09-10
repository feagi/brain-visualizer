extends SubViewportContainer
class_name UI_BrainMonitor_3DScene
## Handles running the scene of Brain monitor, which shows a single instance of a brain region
# Force re-parse to fix Godot parsing issues
const SCENE_BRAIN_MONITOR_PATH: StringName = "res://addons/UI_BrainMonitor/BrainMonitor.tscn"

@export var multi_select_key: Key = KEY_SHIFT

signal clicked_cortical_area(area: AbstractCorticalArea) ## Clicked cortical area (regardless of context)
signal cortical_area_selected_neurons_changed(area: AbstractCorticalArea, selected_neuron_coordinates: Array[Vector3i])
signal cortical_area_selected_neurons_changed_delta(area: AbstractCorticalArea, selected_neuron_coordinate: Vector3i, is_added: bool)
signal requesting_to_fire_selected_neurons(area_IDs_and_neuron_coordinates: Dictionary[StringName, Array]) # NOTE: Array is of type Array[Vector3i]
signal requesting_to_clear_all_selected_neurons()

var representing_region: BrainRegion:
	get: return _representing_region

var _node_3D_root: Node3D
var _pancake_cam: UI_BrainMonitor_PancakeCamera
var _UI_layer_for_BM: UI_BrainMonitor_Overlay = null


var _representing_region: BrainRegion
var _world_3D: World3D # used for physics stuff
var _cortical_visualizations_by_ID: Dictionary[StringName, UI_BrainMonitor_CorticalArea]
var _brain_region_visualizations_by_ID: Dictionary  # Dictionary[StringName, UI_BrainMonitor_BrainRegion3D]
var _active_previews: Array[UI_BrainMonitor_InteractivePreview] = []
var _restrict_neuron_selection_to: AbstractCorticalArea = null

var _previously_moused_over_volumes: Array[UI_BrainMonitor_CorticalArea] = []
var _previously_moused_over_cortical_area_neurons: Dictionary[UI_BrainMonitor_CorticalArea, Array] = {} # where Array is an Array of Vector3i representing Neuron Coordinates



## Spawns an non-setup Brain Visualizer Scene. # WARNING be sure to add it to the scene tree before running setup on it!
static func create_uninitialized_brain_monitor() -> UI_BrainMonitor_3DScene:
	return load(SCENE_BRAIN_MONITOR_PATH).instantiate()

func _ready() -> void:
	_node_3D_root = $SubViewport/Center
	_UI_layer_for_BM = $SubViewport/BM_UI
	
	# TODO check mode (PC)
	_pancake_cam = $SubViewport/Center/PancakeCam
	if _pancake_cam:
		_pancake_cam.BM_input_events.connect(_process_user_input)
		
		# Ensure SubViewport has a World3D with proper environment
		var subviewport = $SubViewport as SubViewport
		if subviewport.world_3d == null:
			# Tab brain monitors need SEPARATE World3D to avoid seeing main content
			if BV.UI.temp_root_bm and BV.UI.temp_root_bm != self:
				var main_viewport = BV.UI.temp_root_bm.get_child(0) as SubViewport
				if main_viewport.world_3d != null:
					subviewport.world_3d = _create_world3d_with_environment()
				else:
					var shared_world = _create_world3d_with_environment()
					subviewport.world_3d = shared_world
					main_viewport.world_3d = shared_world
			else:
				subviewport.world_3d = _create_world3d_with_environment()
		
		_world_3D = _pancake_cam.get_world_3d()
	

func setup(region: BrainRegion) -> void:
	_representing_region = region
	name = "BM_" + region.region_ID

	print("BrainMonitor 3D Scene: SETUP STARTED for region: %s" % region.friendly_name)
	

	

	
	# Create cortical areas from target region
	for area in _representing_region.contained_cortical_areas:
		_add_cortical_area(area)
	
	# Check cortical areas in child regions that might be I/O areas
	print("🔍 SETUP: Checking child regions for I/O cortical areas...")
	for child_region in _representing_region.contained_regions:
		print("  🏗️ Child region: %s (contains %d areas)" % [child_region.friendly_name, child_region.contained_cortical_areas.size()])
		for area in child_region.contained_cortical_areas:
			print("    🔍 Checking area: %s" % area.cortical_ID)
			var is_io = _is_area_input_output_of_specific_child_region(area, child_region)
			print("    📋 Is I/O area: %s" % is_io)
			if is_io:
				print("    ✅ Creating visualization for I/O area: %s" % area.cortical_ID)
				_add_cortical_area(area)
			else:
				print("    ⏭️ Skipping non-I/O area: %s" % area.cortical_ID)
	
	# Create child brain region frames
	for child_region in _representing_region.contained_regions:
		_add_brain_region_frame(child_region)
	


	




	# Connect to region signals for dynamic updates
	_representing_region.cortical_area_added_to_region.connect(_add_cortical_area)
	_representing_region.cortical_area_removed_from_region.connect(_remove_cortical_area)
	_representing_region.subregion_added_to_region.connect(_add_brain_region_frame)
	_representing_region.subregion_removed_from_region.connect(_remove_brain_region_frame)

	# Position camera to focus on region's areas
	if _pancake_cam and region.contained_cortical_areas.size() > 0:
		var center_pos = Vector3.ZERO
		for area in region.contained_cortical_areas:
			center_pos += Vector3(area.coordinates_3D)
		center_pos /= region.contained_cortical_areas.size()
		_pancake_cam.position = center_pos + Vector3(0, 50, 100)
		_pancake_cam.look_at(center_pos, Vector3.UP)
	
	# Add subtle label for non-root regions (tab brain monitors)
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	if region != root_region:
		var label_3d = Label3D.new()
		label_3d.text = "TAB: %s\n%d areas from this region" % [region.friendly_name, region.contained_cortical_areas.size()]
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.modulate = Color.YELLOW
		label_3d.pixel_size = 0.01
		label_3d.font_size = 32
		label_3d.outline_size = 4
		label_3d.outline_modulate = Color.BLACK
		
		if region.contained_cortical_areas.size() > 0:
			var center_pos = Vector3.ZERO
			for area in region.contained_cortical_areas:
				center_pos += Vector3(area.coordinates_3D)
			center_pos /= region.contained_cortical_areas.size()
			label_3d.position = center_pos + Vector3(0, 30, 0)
		else:
			label_3d.position = Vector3(0, 30, 0)
		
		_node_3D_root.add_child(label_3d)
	
	# Connect to cache reload events to refresh all cortical area connections
	if FeagiCore.feagi_local_cache:
		FeagiCore.feagi_local_cache.cache_reloaded.connect(_on_cache_reloaded_refresh_all_connections)
		# print("BrainMonitor 3D Scene: 🔗 CONNECTED to cache reload signal for global connection refresh")  # Suppressed - causes output overflow

func _create_world3d_with_environment() -> World3D:
	var new_world = World3D.new()
	
	# Try to copy environment from the main scene's viewport
	var main_viewport = get_viewport()
	if main_viewport and main_viewport.world_3d and main_viewport.world_3d.environment:
		new_world.environment = main_viewport.world_3d.environment
		return new_world
	
	# Fallback: Create basic environment if can't copy
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0951993, 0.544281, 0.999948, 1)  # Sky blue
	new_world.environment = environment
	
	return new_world


func _update_tab_title_after_setup() -> void:
	if _representing_region and get_parent() is TabContainer:
		var tab_container = get_parent() as TabContainer
		var tab_index = tab_container.get_tab_idx_from_control(self)
		if tab_index >= 0:
			tab_container.set_tab_title(tab_index, _representing_region.friendly_name)


func _process_user_input(bm_input_events: Array[UI_BrainMonitor_InputEvent_Abstract]) -> void:
	var current_space: PhysicsDirectSpaceState3D = _world_3D.direct_space_state
	var currently_moused_over_volumes: Array[UI_BrainMonitor_CorticalArea] = []
	var currently_mousing_over_neurons: Dictionary[UI_BrainMonitor_CorticalArea, Array] = {} # where Array is an Array of Vector3i representing Neuron Coordinates
	
	for bm_input_event in bm_input_events: # multiple events can happen at once
		
		if bm_input_event is UI_BrainMonitor_InputEvent_Hover:
			var hit: Dictionary = current_space.intersect_ray(bm_input_event.get_ray_query())
			if hit.is_empty():
				# Mousing over nothing right now
				
				_UI_layer_for_BM.clear() # temp!
				
				continue
				
			var hit_body: StaticBody3D = hit[&"collider"]
			
			# Check if we hit a cortical area renderer
			if hit_body.get_parent() is UI_BrainMonitor_AbstractCorticalAreaRenderer:
				var hit_parent: UI_BrainMonitor_AbstractCorticalAreaRenderer = hit_body.get_parent()
				if not hit_parent:
					continue # this shouldn't be possible
				var hit_world_location: Vector3 = hit["position"]
				var hit_parent_parent: UI_BrainMonitor_CorticalArea = hit_parent.get_parent_BM_abstraction()
				var neuron_coordinate_mousing_over: Vector3i = hit_parent.world_godot_position_to_neuron_coordinate(hit_world_location)
				if not hit_parent_parent:
					continue # this shouldnt be possible
				
				currently_moused_over_volumes.append(hit_parent_parent)
				if hit_parent_parent in currently_mousing_over_neurons:
					if neuron_coordinate_mousing_over not in currently_mousing_over_neurons[hit_parent_parent]:
						currently_mousing_over_neurons[hit_parent_parent].append(neuron_coordinate_mousing_over)
				else:
					var typed_arr: Array[Vector3i] = [neuron_coordinate_mousing_over]
					currently_mousing_over_neurons[hit_parent_parent] = typed_arr
				
				_UI_layer_for_BM.mouse_over_single_cortical_area(hit_parent_parent.cortical_area, neuron_coordinate_mousing_over)# temp!
			
			# Check if we hit a brain region frame (by checking script global name)
			elif hit_body.get_parent() and hit_body.get_parent().get_script() and hit_body.get_parent().get_script().get_global_name() == "UI_BrainMonitor_BrainRegion3D":
				var region_frame = hit_body.get_parent()  # UI_BrainMonitor_BrainRegion3D
				if region_frame:
					region_frame.set_hover_state(true)
					print("🧠 Hovering over red line wireframe brain region: %s" % region_frame.representing_region.friendly_name)
			
		elif bm_input_event is UI_BrainMonitor_InputEvent_Click:
			
			# special cases for actions
			if bm_input_event.button == UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.FIRE_SELECTED_NEURONS && bm_input_event.button_pressed: # special case when firing neurons
				# Process FIRE_SELECTED_NEURONS event
				var dict: Dictionary[StringName, Array] = {}
				for BM_cortical_area in _cortical_visualizations_by_ID.values():
					var selected_neurons: Array[Vector3i] = BM_cortical_area.get_neuron_selection_states()
					if !selected_neurons.is_empty():
						dict[BM_cortical_area.cortical_area.cortical_ID] = selected_neurons
				# Emit signal to fire selected neurons
				requesting_to_fire_selected_neurons.emit(dict)
				return
			if bm_input_event.button == UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.CLEAR_ALL_SELECTED_NEURONS && bm_input_event.button_pressed: # special case when clearing all neurons
				for bm_cortical_area in _cortical_visualizations_by_ID.values():
					bm_cortical_area.clear_all_neuron_selection_states() # slow but I dont care right now
			
			
			
			var hit: Dictionary = current_space.intersect_ray(bm_input_event.get_ray_query())
			if hit.is_empty():
				# Clicking over nothing
				continue
				
			var hit_body: StaticBody3D = hit[&"collider"]
			
			# Check if we hit a cortical area renderer
			if hit_body.get_parent() is UI_BrainMonitor_AbstractCorticalAreaRenderer:
				var hit_parent: UI_BrainMonitor_AbstractCorticalAreaRenderer = hit_body.get_parent()
				if not hit_parent:
					continue # this shouldn't be possible
				var hit_world_location: Vector3 = hit["position"]
				var hit_parent_parent: UI_BrainMonitor_CorticalArea = hit_parent.get_parent_BM_abstraction()
				var neuron_coordinate_clicked: Vector3i = hit_parent.world_godot_position_to_neuron_coordinate(hit_world_location)
				if hit_parent_parent:
					currently_moused_over_volumes.append(hit_parent_parent)
					var arr_test: Array[GenomeObject] = [hit_parent_parent.cortical_area]
					if bm_input_event.button_pressed:
						if UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.HOLD_TO_SELECT_NEURONS in bm_input_event.all_buttons_being_held:
							var is_neuron_selected: bool = hit_parent_parent.toggle_neuron_selection_state(neuron_coordinate_clicked)
							cortical_area_selected_neurons_changed.emit(hit_parent_parent.cortical_area, hit_parent_parent.get_neuron_selection_states())
							cortical_area_selected_neurons_changed_delta.emit(hit_parent_parent.cortical_area, neuron_coordinate_clicked, is_neuron_selected)
						else:
							if bm_input_event.button == UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.MAIN:
								
								BV.UI.selection_system.select_objects(SelectionSystem.SOURCE_CONTEXT.UNKNOWN, arr_test)
								BV.UI.selection_system.cortical_area_voxel_clicked(hit_parent_parent.cortical_area, neuron_coordinate_clicked)
								#BV.UI.window_manager.spawn_quick_cortical_menu(arr_test)
								#clicked_cortical_area.emit(hit_parent_parent.cortical_area)
			
			# Check if we hit a brain region frame (by checking script global name)
			elif hit_body.get_parent() and hit_body.get_parent().get_script() and hit_body.get_parent().get_script().get_global_name() == "UI_BrainMonitor_BrainRegion3D":
				var region_frame = hit_body.get_parent()  # UI_BrainMonitor_BrainRegion3D
				if region_frame and bm_input_event.button_pressed:
					if bm_input_event.button == UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.MAIN:
						# Single click on brain region - select it
						BV.UI.selection_system.clear_all_highlighted()
						BV.UI.selection_system.add_to_highlighted(region_frame.representing_region)
						BV.UI.selection_system.select_objects(SelectionSystem.SOURCE_CONTEXT.UNKNOWN)
						print("🧠 Clicked brain region frame: %s" % region_frame.representing_region.friendly_name)
						
						# Check for double-click (simple implementation)
						region_frame.handle_double_click()
			
	
	# Higlight what has been moused over (and unhighlight what hasnt) (this is slow but not really a problem right now)
	for previously_moused_over_volume in _previously_moused_over_volumes:
		if previously_moused_over_volume not in currently_moused_over_volumes:
			previously_moused_over_volume.set_hover_over_volume_state(false)
	for currently_moused_over_volume in currently_moused_over_volumes:
		if currently_moused_over_volume not in _previously_moused_over_volumes:
			currently_moused_over_volume.set_hover_over_volume_state(true)
	_previously_moused_over_volumes = currently_moused_over_volumes
	
	# highlight neurons that are moused over (and unhighlight what wasnt)
	currently_mousing_over_neurons.merge(_previously_moused_over_cortical_area_neurons, false)
	for cortical_area in currently_mousing_over_neurons.keys():
		var typed_arr: Array[UI_BrainMonitor_CorticalArea] = []
		if len(currently_mousing_over_neurons[cortical_area]) == 0:
			# Cortical area has nothing hovering over it, tell the renderer to clear it
			cortical_area.clear_hover_state_for_all_neurons()
			currently_mousing_over_neurons.erase(cortical_area)
		else:
			# cortical area has things hovering over it, tell renderer to show it
			cortical_area.set_highlighted_neurons(currently_mousing_over_neurons[cortical_area])
		currently_mousing_over_neurons[cortical_area] = typed_arr
	_previously_moused_over_cortical_area_neurons = currently_mousing_over_neurons

#region Interaction

func clear_all_selected_cortical_area_neurons() -> void:
	for area: UI_BrainMonitor_CorticalArea in _cortical_visualizations_by_ID.values():
		area.clear_all_neuron_selection_states()

func set_further_neuron_selection_restriction_to_cortical_area(restrict_to: AbstractCorticalArea) -> void:
	if restrict_to.cortical_ID in _cortical_visualizations_by_ID:
		_restrict_neuron_selection_to = restrict_to

func remove_neuron_cortical_are_selection_restrictions() -> void:
	_restrict_neuron_selection_to = null

## Allows any external element to create a 3D preview in this BM that it can edit and free as needed
func create_preview(initial_FEAGI_position: Vector3i, initial_dimensions: Vector3i, show_voxels: bool, cortical_area_type: AbstractCorticalArea.CORTICAL_AREA_TYPE = AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN, existing_cortical_area: AbstractCorticalArea = null) -> UI_BrainMonitor_InteractivePreview:
	var preview: UI_BrainMonitor_InteractivePreview = UI_BrainMonitor_InteractivePreview.new()
	_node_3D_root.add_child(preview)  # CRITICAL FIX: Add to 3D scene root, not brain monitor container
	preview.setup(initial_FEAGI_position, initial_dimensions, show_voxels, cortical_area_type, existing_cortical_area)
	_active_previews.append(preview)
	preview.tree_exiting.connect(_preview_closing)
	return preview

## Allows external elements to create a brain region preview showing dual plates
func create_brain_region_preview(brain_region: BrainRegion, initial_FEAGI_position: Vector3i) -> UI_BrainMonitor_BrainRegionPreview:
	var preview: UI_BrainMonitor_BrainRegionPreview = UI_BrainMonitor_BrainRegionPreview.new()
	_node_3D_root.add_child(preview)  # Add to 3D scene root
	preview.setup(brain_region, initial_FEAGI_position)
	preview.tree_exiting.connect(_brain_region_preview_closing)
	print("🔮 Created brain region preview for: %s" % brain_region.friendly_name)
	return preview

## Closes all currently active previews
func clear_all_open_previews() -> void:
	var previews_duplicated: Array[UI_BrainMonitor_InteractivePreview] = _active_previews.duplicate()
	for active_preview in previews_duplicated:
		if active_preview:
			active_preview.queue_free()
	_active_previews = []

## Called when the preview is about to be free'd for any reason
func _preview_closing(preview: UI_BrainMonitor_InteractivePreview):
	_active_previews.erase(preview)

## Called when a brain region preview is about to be freed
func _brain_region_preview_closing(preview: UI_BrainMonitor_BrainRegionPreview):
	print("🔮 Brain region preview closing: %s" % preview.name)


#endregion


#region Cache Responses

# NOTE: Cortical area movements, resizes, and renames are handled by the [UI_BrainMonitor_CorticalArea]s themselves!

func _add_cortical_area(area: AbstractCorticalArea) -> UI_BrainMonitor_CorticalArea:
	# print("🚨 _add_cortical_area() CALLED for area: %s in brain monitor instance %d (region: %s)" % [area.cortical_ID, get_instance_id(), _representing_region.friendly_name])  # Suppressed - causes output overflow
	
	# Show call stack to find who's calling this - SUPPRESSED DUE TO OUTPUT OVERFLOW
	# print("🚨 CALL STACK for _add_cortical_area:")
	# var stack = get_stack()
	# stack.reverse()
	# for i in range(min(3, stack.size())):
	# 	var frame = stack[i]
	# 	print("  %d. %s:%s in %s()" % [i, frame.source, frame.line, frame.function])
	if area.cortical_ID in _cortical_visualizations_by_ID:
		push_warning("Unable to add to BM already existing cortical area of ID %s!" % area.cortical_ID)
		return null
	
	# Check if this area should be created
	var is_directly_in_root = _representing_region.is_cortical_area_in_region_directly(area)
	var is_io_of_child_region = _is_area_input_output_of_child_region(area)
	
	print("  🔍 FILTERING ANALYSIS for area %s:" % area.cortical_ID)
	print("    - Representing region: %s" % _representing_region.friendly_name)
	print("    - Area region: %s" % (area.current_parent_region.friendly_name if area.current_parent_region else "None"))
	print("    - Is directly in root: %s" % is_directly_in_root)
	print("    - Is I/O of child region: %s" % is_io_of_child_region)
	
	# Only create if the area is directly in root OR it's needed as I/O for a child region
	if not is_directly_in_root and not is_io_of_child_region:
		print("  ⏭️  Skipping cortical area %s - not directly in root region and not I/O of child region" % area.cortical_ID)
		return null
	
	print("  ✅ Creating cortical area %s - directly_in_root: %s, io_of_child: %s" % [area.cortical_ID, is_directly_in_root, is_io_of_child_region])
	# print("  🎯 CRITICAL: Adding %s to 3D scene of brain monitor for region %s" % [area.cortical_ID, _representing_region.friendly_name])  # Suppressed - too verbose
	# print("  🎯 INSTANCE: Adding to brain monitor instance %d" % get_instance_id())  # Suppressed - too verbose
	# print("  🎯 INSTANCE: Adding to 3D root %s (instance %d)" % [_node_3D_root, _node_3D_root.get_instance_id()])  # Suppressed - too verbose
	
	var rendering_area: UI_BrainMonitor_CorticalArea = UI_BrainMonitor_CorticalArea.new()
	_node_3D_root.add_child(rendering_area)
	# print("  🎯 ADDED: Cortical area %s added as child to 3D root instance %d" % [area.cortical_ID, _node_3D_root.get_instance_id()])  # Suppressed - too verbose
	rendering_area.setup(area)
	_cortical_visualizations_by_ID[area.cortical_ID] = rendering_area
	
	print("  ✅ SUCCESS: Cortical area %s added to brain monitor %s" % [area.cortical_ID, name])
	# print("  📍 Area coordinates: %s" % area.coordinates_3D)  # Suppressed - too frequent
	# print("  🎯 Total areas in this brain monitor: %d" % _cortical_visualizations_by_ID.size())  # Suppressed - too frequent
	
	area.about_to_be_deleted.connect(_remove_cortical_area.bind(area))
	area.coordinates_3D_updated.connect(rendering_area.set_new_position)
	
	# If this area is I/O of a child region, it will be moved later by the brain region component
	# For now, position it normally - it will be repositioned when brain regions populate
	if is_io_of_child_region:
		print("  🔧 Created I/O area %s - will be repositioned by brain region wireframe" % area.cortical_ID)
	
	return rendering_area

## Gets an existing cortical area visualization by ID (used by brain region frames)
func get_cortical_area_visualization(cortical_id: String) -> UI_BrainMonitor_CorticalArea:
	return _cortical_visualizations_by_ID.get(cortical_id, null)

## Check if this brain monitor is currently visualizing a specific cortical area
func has_cortical_area_visualization(cortical_id: String) -> bool:
	return cortical_id in _cortical_visualizations_by_ID

func _remove_cortical_area(area: AbstractCorticalArea) -> void:
	if area.cortical_ID not in _cortical_visualizations_by_ID:
		push_warning("Unable to remove from BM nonexistant cortical area of ID %s!" % area.cortical_ID)
		return
	var rendering_area: UI_BrainMonitor_CorticalArea = _cortical_visualizations_by_ID[area.cortical_ID]
	_previously_moused_over_volumes.erase(rendering_area)
	_previously_moused_over_cortical_area_neurons.erase(rendering_area)
	rendering_area.queue_free()
	_cortical_visualizations_by_ID.erase(area.cortical_ID)

func _add_brain_region_frame(brain_region: BrainRegion):  # -> UI_BrainMonitor_BrainRegion3D
	# print("🚨🚨🚨 DEBUG: _add_brain_region_frame called for: %s" % brain_region.friendly_name)  # Suppressed - causes output overflow
	print("  🔧 _add_brain_region_frame called for: %s" % brain_region.friendly_name)
	print("  📍 Brain region coordinates: 2D=%s, 3D=%s" % [brain_region.coordinates_2D, brain_region.coordinates_3D])
	
	if brain_region.region_ID in _brain_region_visualizations_by_ID:
		push_warning("Unable to add to BM already existing brain region of ID %s!" % brain_region.region_ID)
		return null
	
	print("  🏭 Creating UI_BrainMonitor_BrainRegion3D instance...")
	var brain_region_script = load("res://addons/UI_BrainMonitor/UI_BrainMonitor_BrainRegion3D.gd")
	var region_frame = brain_region_script.new()  # UI_BrainMonitor_BrainRegion3D
	print("  📍 Adding to _node_3D_root...")
	_node_3D_root.add_child(region_frame)
	print("  📍 DEBUG: Main region parent: %s" % region_frame.get_parent().name)
	print("  📍 DEBUG: Main region parent transform: %s" % region_frame.get_parent().transform)
	print("  🔧 Calling region_frame.setup()...")
	print("  🔍 DEBUG: Brain region coordinates before setup: %s" % brain_region.coordinates_3D)
	region_frame.setup(brain_region)
	print("  💾 Storing in _brain_region_visualizations_by_ID...")
	_brain_region_visualizations_by_ID[brain_region.region_ID] = region_frame
	
	# Connect region frame signals
	print("  🔗 Connecting signals...")
	region_frame.region_double_clicked.connect(_on_brain_region_double_clicked)
	region_frame.region_hover_changed.connect(_on_brain_region_hover_changed)
	brain_region.about_to_be_deleted.connect(_remove_brain_region_frame.bind(brain_region))
	
	print("  ✅ Brain region frame setup complete for: %s" % brain_region.friendly_name)
	return region_frame

func _remove_brain_region_frame(brain_region: BrainRegion) -> void:
	if brain_region.region_ID not in _brain_region_visualizations_by_ID:
		push_warning("Unable to remove from BM nonexistant brain region of ID %s!" % brain_region.region_ID)
		return
	var region_frame = _brain_region_visualizations_by_ID[brain_region.region_ID]  # UI_BrainMonitor_BrainRegion3D
	region_frame.queue_free()
	_brain_region_visualizations_by_ID.erase(brain_region.region_ID)

func _on_brain_region_double_clicked(brain_region: BrainRegion) -> void:
	print("🧠 BrainMonitor: Brain region double-clicked: %s" % brain_region.friendly_name)
	# TODO: Implement navigation/diving into brain region (future tab system)
	
func _on_brain_region_hover_changed(brain_region: BrainRegion, is_hovered: bool) -> void:
	print("🧠 BrainMonitor: Brain region hover changed: %s, hovered: %s" % [brain_region.friendly_name, is_hovered])

## Checks if a cortical area is I/O of a specific child region (using same logic as brain region)
func _is_area_input_output_of_specific_child_region(area: AbstractCorticalArea, child_region: BrainRegion) -> bool:
	# Checking if area is I/O of specific child region - debug output suppressed
	
	# Method 1: Check connection chain links first
	# Checking input chain links - debug output suppressed
	for link: ConnectionChainLink in child_region.input_open_chain_links:
		if link.destination == area:
			print("        ✅ Found as INPUT via chain link!")
			return true
	
	# print("        📤 Checking %d output_open_chain_links..." % child_region.output_open_chain_links.size())  # Suppressed - too spammy
	for link: ConnectionChainLink in child_region.output_open_chain_links:
		if link.source == area:
			print("        ✅ Found as OUTPUT via chain link!")
			return true
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays) - CRITICAL FIX!
	for partial_mapping in child_region.partial_mappings:
		if partial_mapping.internal_target_cortical_area == area:
			if partial_mapping.is_region_input:
				print("        ✅ Found as INPUT via partial mapping (FEAGI inputs array)!")
			else:
				print("        ✅ Found as OUTPUT via partial mapping (FEAGI outputs array)!")
			return true
	
	# Method 3: Check IPU/OPU types
	if area in child_region.contained_cortical_areas:
		if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			print("        ✅ Found as IPU type directly in child region!")
			return true
		elif area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			print("        ✅ Found as OPU type directly in child region!")
			return true
	
	# Method 4: TEMPORARY aggressive naming heuristics (for debugging - will restore conservative logic after)
	if child_region.input_open_chain_links.size() == 0 and child_region.output_open_chain_links.size() == 0:
		if area in child_region.contained_cortical_areas and child_region.contained_cortical_areas.size() == 2:
			print("        💡 TEMPORARY: Using aggressive naming heuristics for debugging...")
			var area_id = area.cortical_ID.to_lower()
			# Check for input patterns  
			if "lef" in area_id or "left" in area_id or "input" in area_id or "in" in area_id:
				print("        ✅ AGGRESSIVE: Found as INPUT via naming heuristic (contains '%s')!" % area_id)
				return true
			# Check for output patterns (c__rig should be output per FEAGI data)
			if "rig" in area_id or "right" in area_id or "output" in area_id or "out" in area_id:
				print("        ✅ AGGRESSIVE: Found as OUTPUT via naming heuristic (contains '%s')!" % area_id)
				return true
	
	# print("        ❌ Area %s is NOT I/O of child region '%s'" % [area.cortical_ID, child_region.friendly_name])  # Suppressed - too spammy
	return false

## Checks if a cortical area is used as input/output by any child brain regions (using same logic as specific method)
func _is_area_input_output_of_child_region(area: AbstractCorticalArea) -> bool:
	# Check all child brain regions to see if this area is their I/O
	# print("    🔍 Checking if area %s is I/O of any child region..." % area.cortical_ID)  # Suppressed - too spammy
	
	for child_region: BrainRegion in _representing_region.contained_regions:
		# print("      🏗️ Checking child region: %s" % child_region.friendly_name)  # Suppressed - too spammy
		
		# Use the SAME logic as _is_area_input_output_of_specific_child_region
		if _is_area_input_output_of_specific_child_region(area, child_region):
			print("      ✅ Found as I/O of child region '%s'!" % child_region.friendly_name)
			return true
	
	# print("    ❌ Area %s is NOT I/O of any child region" % area.cortical_ID)  # Suppressed - too spammy
	return false

## Cache reload event handler - refreshes all cortical area connections
func _on_cache_reloaded_refresh_all_connections() -> void:
	print("BrainMonitor 3D Scene: 🔄 CACHE RELOAD detected - refreshing all cortical area connections")
	
	# Force refresh connections for all currently hovered cortical areas
	var refreshed_count = 0
	for cortical_viz in _cortical_visualizations_by_ID.values():
		if cortical_viz._is_volume_moused_over:
			print("   🔗 Refreshing connections for hovered area: ", cortical_viz.cortical_area.cortical_ID)
			cortical_viz._hide_neural_connections()
			cortical_viz._show_neural_connections()
			refreshed_count += 1
	
	print("BrainMonitor 3D Scene: ✅ Refreshed connections for ", refreshed_count, " hovered cortical areas")

## Manual force refresh of all cortical area connections (for debugging/troubleshooting)
func force_refresh_all_cortical_connections() -> void:
	print("BrainMonitor 3D Scene: 🔧 MANUAL REFRESH - Force refreshing all cortical area connections")
	
	var refreshed_count = 0
	for cortical_viz in _cortical_visualizations_by_ID.values():
		# Hide any existing connections
		cortical_viz._hide_neural_connections()
		
		# If this area is currently hovered, show refreshed connections
		if cortical_viz._is_volume_moused_over:
			cortical_viz._show_neural_connections()
			refreshed_count += 1
	
	print("BrainMonitor 3D Scene: ✅ Manual refresh completed for ", refreshed_count, " areas")

#endregion
