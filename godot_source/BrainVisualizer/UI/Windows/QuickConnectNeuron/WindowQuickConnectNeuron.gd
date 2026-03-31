extends BaseDraggableWindow
class_name WindowQuickConnectNeuron

const WINDOW_NAME: StringName = "quick_connect_neuron"
const MAPPING_UPDATE_WARNING_POPUP_MIN_SIZE: Vector2i = Vector2i(640, 420)

const INVALID_COORD: Vector3i = Vector3i(-1,-1,-1)

enum MODE {
	CORTICAL_AREA_TO_NEURONS,
	NEURONS_TO_CORTICAL_AREA,
	NEURON_TO_NEURONS
}

enum POSSIBLE_STATES {
	NOT_READY,
	SOURCE,
	DESTINATION,
	READY
}


var current_state: POSSIBLE_STATES:
	get: return _current_state

var _source_panel: PanelContainer
var _source_label: RichTextLabel
var _source_edit_button: TextureButton
var _destination_panel: PanelContainer
var _destination_label: RichTextLabel
var _destination_edit_button: TextureButton
var _mapping_panel: PanelContainer
var _mapping_label: RichTextLabel
var _mapping_edit_button: TextureButton

var _establish_button: Button


var _current_state: POSSIBLE_STATES = POSSIBLE_STATES.NOT_READY
var _finished_selecting: bool = false

var _source: AbstractCorticalArea = null
var _source_neuron_local_coords: Array[Vector3i] = []
var _destination: AbstractCorticalArea = null
var _destination_neuron_local_coords: Array[Vector3i] = []

var _mode: MODE
var _establishing: bool = false

func _ready() -> void:
	super()
	_source_panel = _window_internals.get_node("source")
	_source_label = _window_internals.get_node("source/step1/Label")
	_source_edit_button = _window_internals.get_node("source/step1/TextureButton")
	_destination_panel = _window_internals.get_node("destination")
	_destination_label = _window_internals.get_node("destination/step2/Label")
	_destination_edit_button = _window_internals.get_node("destination/step2/TextureButton")
	_mapping_panel = _window_internals.get_node("confirm")
	_mapping_label = _window_internals.get_node("confirm/step3/Label")
	_mapping_edit_button = _window_internals.get_node("confirm/step3/TextureButton")
	_establish_button = _window_internals.get_node("Establish")
	
	_source_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	_destination_panel.theme_type_variation = "PanelContainer_QC_incomplete"

	
	
func setup(mode: MODE, optional_initial_cortical_area: AbstractCorticalArea) -> void:
	_setup_base_window(WINDOW_NAME)
	_mode = mode
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT_NEURON)
	_start_edit_source_config(optional_initial_cortical_area)


func _start_edit_source_config(optional_limit_to_cortical_area: AbstractCorticalArea = null) -> void:
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	if _destination_panel.theme_type_variation == "PanelContainer_QC_waiting":
		_end_edit_destination_config()
	_source_panel.theme_type_variation = "PanelContainer_QC_waiting"
	_source = null
	_source_neuron_local_coords = []
	_mapping_edit_button.disabled = true
	_mapping_label.text = "Waiting..."
	_establish_button.disabled = true
	_destination_edit_button.disabled = true
	
	if optional_limit_to_cortical_area != null:
		_source = optional_limit_to_cortical_area
		BV.UI.temp_root_bm.set_further_neuron_selection_restriction_to_cortical_area(optional_limit_to_cortical_area)
		if _mode == MODE.CORTICAL_AREA_TO_NEURONS:
			_update_label_of_source_or_destination(true)
			_end_edit_source_config()
			_start_edit_destination_config()
			return
	BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.connect(_retrieved_source_neuron_list_change)
	_update_label_of_source_or_destination(true)


func _retrieved_source_neuron_list_change(area: AbstractCorticalArea, local_coord: Vector3i, added: bool) -> void:
	if _source == null:
		_source = area
		BV.UI.temp_root_bm.set_further_neuron_selection_restriction_to_cortical_area(area)
	if _source != area:
		push_error("FEAGI Quick Neuron Connect: Source area does not match expected!")
		return
	_destination_edit_button.disabled = false
	if _mode == MODE.CORTICAL_AREA_TO_NEURONS:
		_update_label_of_source_or_destination(true)
		_end_edit_source_config()
		return # we dont care about neurons
	
	if added:
		if local_coord in _source_neuron_local_coords:
			pass
		else:
			_source_neuron_local_coords.append(local_coord)
			if _mode == MODE.NEURON_TO_NEURONS:
				_update_label_of_source_or_destination(true)
				_end_edit_source_config() # only need 1 neuron
				return
	else:
		var search: int = _source_neuron_local_coords.find(local_coord)
		if search != -1:
			_source_neuron_local_coords.remove_at(search)
		return
	_update_label_of_source_or_destination(true)
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()

func _end_edit_source_config() -> void:
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	BV.UI.temp_root_bm.remove_neuron_cortical_are_selection_restrictions()
	_source_panel.theme_type_variation = "PanelContainer_QC_Complete"
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	if BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.is_connected(_retrieved_source_neuron_list_change):
		BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.disconnect(_retrieved_source_neuron_list_change)


func _start_edit_destination_config(optional_limit_to_cortical_area: AbstractCorticalArea = null) -> void:
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	if _source_panel.theme_type_variation == "PanelContainer_QC_waiting":
		_end_edit_source_config()
	_destination_panel.theme_type_variation = "PanelContainer_QC_waiting"
	_destination = null
	_destination_neuron_local_coords = []
	_mapping_edit_button.disabled = true
	_mapping_label.text = "Waiting..."
	_establish_button.disabled = true
	_source_edit_button.disabled = true
	
	if optional_limit_to_cortical_area != null:
		_destination = optional_limit_to_cortical_area
		BV.UI.temp_root_bm.set_further_neuron_selection_restriction_to_cortical_area(optional_limit_to_cortical_area)
		if _mode == MODE.NEURONS_TO_CORTICAL_AREA:
			_update_label_of_source_or_destination(false)
			_end_edit_destination_config()
			return
	BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.connect(_retrieved_destination_neuron_list_change)
	_update_label_of_source_or_destination(false)


func _retrieved_destination_neuron_list_change(area: AbstractCorticalArea, local_coord: Vector3i, added: bool) -> void:
	if _destination == null:
		_destination = area
		BV.UI.temp_root_bm.set_further_neuron_selection_restriction_to_cortical_area(area)
	if _destination != area:
		push_error("FEAGI Quick Neuron Connect: Destination area does not match expected!")
		return
	_source_edit_button.disabled = false
	if _mode == MODE.NEURONS_TO_CORTICAL_AREA:
		_update_label_of_source_or_destination(false)
		_end_edit_destination_config()
		return # we dont care about neurons
	
	if added:
		if local_coord in _destination_neuron_local_coords:
			pass
		else:
			_destination_neuron_local_coords.append(local_coord)
	else:
		var search: int = _destination_neuron_local_coords.find(local_coord)
		if search != -1:
			_destination_neuron_local_coords.remove_at(search)
		return
	_update_label_of_source_or_destination(false)
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()

func _end_edit_destination_config() -> void:
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	BV.UI.temp_root_bm.remove_neuron_cortical_are_selection_restrictions()
	_destination_panel.theme_type_variation = "PanelContainer_QC_Complete"
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	if BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.is_connected(_retrieved_destination_neuron_list_change):
		BV.UI.temp_root_bm.cortical_area_selected_neurons_changed_delta.disconnect(_retrieved_destination_neuron_list_change)




func _mapping_establish_check_pressed() -> void:
	if !_has_enough_information_for_mapping():
		return
	_end_edit_source_config()
	_end_edit_destination_config()
	_define_pattern_morphology_label()
	_establish_button.disabled = false


func _update_label_of_source_or_destination(is_source: bool) -> void:
	var text: String
	if is_source:
		if !_source:
			text = "Select a source cortical area"
		elif _mode == MODE.CORTICAL_AREA_TO_NEURONS:
			text = "Cortical area: %s\nMapping to all neurons!" % _source.friendly_name
		elif len(_source_neuron_local_coords) == 0:
			text = "Cortical area: %s\nPlease select neurons!"  % _source.friendly_name
		else:
			text = "Cortical area: %s\nNeurons:\n"  % _source.friendly_name
			for vector in _source_neuron_local_coords:
				text += "[%d,%d,%d]\n" % [vector.x, vector.y, vector.z]
		_source_label.text = text
		return
	else:
		if !_destination:
			text = "Select a destination cortical area"
		elif _mode == MODE.NEURONS_TO_CORTICAL_AREA:
			text = "Cortical area: %s\nMapping to all neurons!"  % _destination.friendly_name
		elif len(_destination_neuron_local_coords) == 0:
			text = "Cortical area: %s\nPlease select neurons!"  % _destination.friendly_name
		else:
			text = "Cortical area: %s\nNeurons:\n" % _destination.friendly_name
			for vector in _destination_neuron_local_coords:
				text += "[%d,%d,%d]\n" % [vector.x, vector.y, vector.z]
		_destination_label.text = text
		return


func _has_enough_information_for_mapping() -> bool:
	if !_source or !_destination:
		return false
	match _mode:
		MODE.CORTICAL_AREA_TO_NEURONS:
			return len(_destination_neuron_local_coords) != 0
		MODE.NEURONS_TO_CORTICAL_AREA:
			return len(_source_neuron_local_coords) != 0
			
		MODE.NEURON_TO_NEURONS:
			return len(_source_neuron_local_coords) == 1 and len(_destination_neuron_local_coords) > 0
		_:
		# HOW
			return false

func _define_pattern_morphology_label() -> void:
	var text: String = "Source: %s, Destination: %s\n" % [_source.friendly_name, _destination.friendly_name]
	if _source is MemoryCorticalArea:
		text += "Connectivity Rule Type: Projector\n"
		text += "Using Default Projector Settings"
	elif _destination is MemoryCorticalArea:
		text += "Connectivity Rule Type: Memory\n"
		text += "Using Default Memory Settings"
	else:
		text += "Connectivity Rule Type: Pattern\n"
		match _mode:
			MODE.CORTICAL_AREA_TO_NEURONS:
				for vec in _destination_neuron_local_coords:
					text += "[*, *, *] -> [%d, %d, %d]\n" % [vec.x, vec.y, vec.z]
			MODE.NEURONS_TO_CORTICAL_AREA:
				for vec in _source_neuron_local_coords:
					text += "[%d, %d, %d] -> [*, *, *]\n" % [vec.x, vec.y, vec.z]
			MODE.NEURON_TO_NEURONS:
				for vec in _destination_neuron_local_coords:
					text += "[%d, %d, %d] -> [%d, %d, %d]\n" % [_source_neuron_local_coords[0].x, _source_neuron_local_coords[0].y, _source_neuron_local_coords[0].z, vec.x, vec.y, vec.z]
			_:
			# HOW
				return
	_mapping_label.text = text


func _establish() -> void:
	if _establishing: # prevent multiple click spam
		return
	if !_has_enough_information_for_mapping():
		close_window()
		return

	var existing_mappings: Array[SingleMappingDefinition] = _source.get_mapping_array_toward_cortical_area(_destination)
	if existing_mappings.size() > 0:
		var warning_message: String = _build_mapping_update_warning_message(existing_mappings)
		var confirm_action: Callable = _confirm_establish_mapping
		var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_cancel_and_action_popup(
			"Confirm Voxel Mapping Update",
			warning_message,
			confirm_action,
			"Apply Mapping",
			"Cancel",
			MAPPING_UPDATE_WARNING_POPUP_MIN_SIZE
		)
		var popup_window: WindowConfigurablePopup = BV.WM.spawn_popup(popup_definition)
		popup_window.set_enter_confirms_button("Apply Mapping")
		popup_window.call_deferred("focus_button_with_text", "Apply Mapping")
		return

	_confirm_establish_mapping()

func _confirm_establish_mapping() -> void:
	if _establishing:
		return
	_establishing = true
	if _source is MemoryCorticalArea:
		var projector_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies["projector"]
		var out_mem: FeagiRequestOutput = await FeagiCore.requests.append_default_mapping_between_corticals(
			_source,
			_destination,
			projector_morphology,
		)
		_establishing = false
		if out_mem.failed_requirement and out_mem.failed_requirement_key == &"USER_CANCELLED_DESIGNATION":
			return
		if out_mem.success:
			close_window()
		return
	elif _destination is MemoryCorticalArea:
		var memory_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies["episodic_memory"]
		var out_ep: FeagiRequestOutput = await FeagiCore.requests.append_default_mapping_between_corticals(
			_source,
			_destination,
			memory_morphology,
		)
		_establishing = false
		if out_ep.failed_requirement and out_ep.failed_requirement_key == &"USER_CANCELLED_DESIGNATION":
			return
		if out_ep.success:
			close_window()
		return
	else:
		# create a new pattern morphology, then use it in a new mapping
		var morphology_name: StringName = _source.cortical_ID + "_" + _destination.cortical_ID
		var pairs: Array[PatternVector3Pairs]
		match(_mode):
			MODE.CORTICAL_AREA_TO_NEURONS:
				for vec in _destination_neuron_local_coords:
					var incoming: PatternVector3 = PatternVector3.new(PatternVal.new("*"), PatternVal.new("*"), PatternVal.new("*"))
					var outgoing: PatternVector3 = PatternVector3.new(PatternVal.new(vec.x), PatternVal.new(vec.y), PatternVal.new(vec.z))
					morphology_name += "[*,*,*]->[%d,%d,%d]\n" % [vec.x, vec.y, vec.z]
					pairs.append(PatternVector3Pairs.new(incoming, outgoing))
			MODE.NEURONS_TO_CORTICAL_AREA:
				for vec in _source_neuron_local_coords:
					var incoming: PatternVector3 = PatternVector3.new(PatternVal.new(vec.x), PatternVal.new(vec.y), PatternVal.new(vec.z))
					var outgoing: PatternVector3 = PatternVector3.new(PatternVal.new("*"), PatternVal.new("*"), PatternVal.new("*"))
					morphology_name += "[%d,%d,%d]->[*,*,*]\n" % [vec.x, vec.y, vec.z]
					pairs.append(PatternVector3Pairs.new(incoming, outgoing))
			MODE.NEURON_TO_NEURONS:
				for vec in _destination_neuron_local_coords:
					var incoming: PatternVector3 = PatternVector3.new(PatternVal.new(_source_neuron_local_coords[0].x), PatternVal.new(_source_neuron_local_coords[0].y), PatternVal.new(_source_neuron_local_coords[0].z))
					var outgoing: PatternVector3 = PatternVector3.new(PatternVal.new(vec.x), PatternVal.new(vec.y), PatternVal.new(vec.z))
					morphology_name += "[%d,%d,%d]->[%d,%d,%d]\n" % [_source_neuron_local_coords[0].x, _source_neuron_local_coords[0].y, _source_neuron_local_coords[0].z, vec.x, vec.y, vec.z]
					pairs.append(PatternVector3Pairs.new(incoming, outgoing))
		morphology_name = morphology_name.left(16) # limit length
		while morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies:
			morphology_name += "2"
		var response: FeagiRequestOutput = await FeagiCore.requests.add_pattern_morphology(morphology_name, pairs)
		
		if !response.success:
			push_error("FEAGI: Failed to create morphology needed for quick connect!")
			_establishing = false
			close_window()
			return
		var new_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name]
		var out_pat: FeagiRequestOutput = await FeagiCore.requests.append_default_mapping_between_corticals(
			_source,
			_destination,
			new_morphology,
		)
		_establishing = false
		if out_pat.failed_requirement and out_pat.failed_requirement_key == &"USER_CANCELLED_DESIGNATION":
			return
		if not out_pat.success:
			return
		close_window()

func _build_mapping_update_warning_message(existing_mappings: Array[SingleMappingDefinition]) -> String:
	var mapping_lines: PackedStringArray = []
	for mapping: SingleMappingDefinition in existing_mappings:
		if mapping == null:
			continue
		var morphology_name: String = "UNKNOWN"
		if mapping.morphology_used != null:
			morphology_name = mapping.morphology_used.name
		var scalar: Vector3i = mapping.scalar
		mapping_lines.append(
			"%s (scalar: [%d, %d, %d], plasticity: %s)"
			% [morphology_name, scalar.x, scalar.y, scalar.z, str(mapping.is_plastic)]
		)
	var listing: String = "- " + "\n- ".join(mapping_lines)
	return (
		"Updating voxel-level mappings from '%s' to '%s' will update the full cortical mapping edge.\n"
		+ "FEAGI will prune and regenerate synapses for this source -> destination pair.\n\n"
		+ "Existing mapping rule(s) on this edge (%d):\n%s"
	) % [_source.friendly_name, _destination.friendly_name, existing_mappings.size(), listing]

## True only while "area -> specific neuron block" is actively waiting for destination voxel picking.
func is_waiting_for_single_destination_voxel_selection() -> bool:
	if _mode != MODE.CORTICAL_AREA_TO_NEURONS:
		return false
	if _destination_panel == null:
		return false
	return _destination_panel.theme_type_variation == "PanelContainer_QC_waiting"

## Returns true when this window is waiting for any voxel selection step and main-click should pick voxels.
func expects_voxel_selection_on_primary_click() -> bool:
	if _source_panel == null or _destination_panel == null:
		return false

	var source_waiting: bool = _source_panel.theme_type_variation == "PanelContainer_QC_waiting"
	var destination_waiting: bool = _destination_panel.theme_type_variation == "PanelContainer_QC_waiting"
	match _mode:
		MODE.CORTICAL_AREA_TO_NEURONS:
			return destination_waiting
		MODE.NEURONS_TO_CORTICAL_AREA:
			return source_waiting
		MODE.NEURON_TO_NEURONS:
			return source_waiting or destination_waiting
		_:
			return false

## Returns true when the active step expects selecting only a cortical area (not specific voxels).
func expects_entire_area_selection_on_primary_click() -> bool:
	if _source_panel == null or _destination_panel == null:
		return false

	var source_waiting: bool = _source_panel.theme_type_variation == "PanelContainer_QC_waiting"
	var destination_waiting: bool = _destination_panel.theme_type_variation == "PanelContainer_QC_waiting"
	match _mode:
		MODE.CORTICAL_AREA_TO_NEURONS:
			return source_waiting
		MODE.NEURONS_TO_CORTICAL_AREA:
			return destination_waiting
		MODE.NEURON_TO_NEURONS:
			return false
		_:
			return false


func close_window():
	super()
	BV.UI.temp_root_bm.clear_all_selected_cortical_area_neurons()
	BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT_NEURON)
	# Backward-safe cleanup in case a stale QUICK_CONNECT override was previously added.
	BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT)
