extends BaseDraggableWindow
class_name WindowQuickConnectNeuron

const WINDOW_NAME: StringName = "quick_connect_neuron"

const INVALID_COORD: Vector3i = Vector3i(-1,-1,-1)

enum MODE {
	CORTICAL_AREA_TO_NEURONS,
	NEURONS_TO_CORTICAL_AREA,
	NEURON_TO_NEURON
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

	
	
	BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT_NEURON)


func setup(mode: MODE, optional_initial_cortical_area: AbstractCorticalArea) -> void:
	_setup_base_window(WINDOW_NAME)
	_mode = mode
	BV.BM.clear_all_selections()
	BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT)
	_start_edit_source_config(optional_initial_cortical_area)


func _start_edit_source_config(optional_limit_to_cortical_area: AbstractCorticalArea = null) -> void:
	BV.BM.clear_all_selections()
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
		BV.BM.limit_neuron_selection_to_cortical_area = optional_limit_to_cortical_area
		if _mode == MODE.CORTICAL_AREA_TO_NEURONS:
			_update_label_of_source_or_destination(true)
			_end_edit_source_config()
			_start_edit_destination_config()
			return
	BV.BM.voxel_selected_to_list.connect(_retrieved_source_neuron_list_change)
	_update_label_of_source_or_destination(true)


func _retrieved_source_neuron_list_change(area: AbstractCorticalArea, local_coord: Vector3i, added: bool) -> void:
	if _source == null:
		_source = area
		BV.BM.limit_neuron_selection_to_cortical_area = area
	if _source != area:
		push_error("FEAGI Quick Neuron Connect: Source area does not match expected!")
		return
	_destination_edit_button.disabled = false
	if _mode == MODE.CORTICAL_AREA_TO_NEURONS:
		_update_label_of_source_or_destination(true)
		_end_edit_source_config()
		return # we dont care about neurons
	
	if added:
		if local_coord + area.coordinates_3D in _source_neuron_local_coords:
			pass
		else:
			_source_neuron_local_coords.append(local_coord + area.coordinates_3D)
			if _mode == MODE.NEURON_TO_NEURON:
				_update_label_of_source_or_destination(true)
				_end_edit_source_config() # only need 1 neuron
				return
	else:
		var search: int = _source_neuron_local_coords.find(local_coord + area.coordinates_3D)
		if search != -1:
			_source_neuron_local_coords.remove_at(search)
		return
	_update_label_of_source_or_destination(true)
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()

func _end_edit_source_config() -> void:
	BV.BM.clear_all_selections()
	BV.BM.limit_neuron_selection_to_cortical_area = null
	_source_panel.theme_type_variation = "PanelContainer_QC_Complete"
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	if BV.BM.voxel_selected_to_list.is_connected(_retrieved_source_neuron_list_change):
		BV.BM.voxel_selected_to_list.disconnect(_retrieved_source_neuron_list_change)
	BV.BM.limit_neuron_selection_to_cortical_area = null


func _start_edit_destination_config(optional_limit_to_cortical_area: AbstractCorticalArea = null) -> void:
	BV.BM.clear_all_selections()
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
		BV.BM.limit_neuron_selection_to_cortical_area = optional_limit_to_cortical_area
		if _mode == MODE.NEURONS_TO_CORTICAL_AREA:
			_update_label_of_source_or_destination(false)
			_end_edit_destination_config()
			return
	BV.BM.voxel_selected_to_list.connect(_retrieved_destination_neuron_list_change)
	_update_label_of_source_or_destination(false)


func _retrieved_destination_neuron_list_change(area: AbstractCorticalArea, local_coord: Vector3i, added: bool) -> void:
	if _destination == null:
		_destination = area
		BV.BM.limit_neuron_selection_to_cortical_area = area
	if _destination != area:
		push_error("FEAGI Quick Neuron Connect: Destination area does not match expected!")
		return
	_source_edit_button.disabled = false
	if _mode == MODE.NEURONS_TO_CORTICAL_AREA:
		_update_label_of_source_or_destination(false)
		_end_edit_destination_config()
		return # we dont care about neurons
	
	if added:
		if local_coord + area.coordinates_3D in _destination_neuron_local_coords:
			pass
		else:
			_destination_neuron_local_coords.append(local_coord + area.coordinates_3D)
			if _mode == MODE.NEURON_TO_NEURON:
				_update_label_of_source_or_destination(false)
				_end_edit_destination_config() # only need 1 neuron
				return
	else:
		var search: int = _destination_neuron_local_coords.find(local_coord + area.coordinates_3D)
		if search != -1:
			_destination_neuron_local_coords.remove_at(search)
		return
	_update_label_of_source_or_destination(false)
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()

func _end_edit_destination_config() -> void:
	BV.BM.clear_all_selections()
	BV.BM.limit_neuron_selection_to_cortical_area = null
	_destination_panel.theme_type_variation = "PanelContainer_QC_Complete"
	_mapping_edit_button.disabled = !_has_enough_information_for_mapping()
	if BV.BM.voxel_selected_to_list.is_connected(_retrieved_destination_neuron_list_change):
		BV.BM.voxel_selected_to_list.disconnect(_retrieved_destination_neuron_list_change)
	BV.BM.limit_neuron_selection_to_cortical_area = null




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
			
		MODE.NEURON_TO_NEURON:
			return len(_source_neuron_local_coords) == 1 and len(_destination_neuron_local_coords) == 1
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
			MODE.NEURON_TO_NEURON:
				text += "[%d, %d, %d] -> [%d, %d, %d]\n" % [_source_neuron_local_coords[0].x, _source_neuron_local_coords[0].y, _source_neuron_local_coords[0].z, _destination_neuron_local_coords[0].x, _destination_neuron_local_coords[0].y, _destination_neuron_local_coords[0].z]
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
	
	_establishing = true
	if _source is MemoryCorticalArea:
		# establish a mapping using projector
		var projector_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies["projector"]
		FeagiCore.requests.append_default_mapping_between_corticals(_source, _destination, projector_morphology)
	elif _destination is MemoryCorticalArea:
		# emmory
		var memory_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies["memory"]
		FeagiCore.requests.append_default_mapping_between_corticals(_source, _destination, memory_morphology)
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
			MODE.NEURON_TO_NEURON:
				var incoming: PatternVector3 = PatternVector3.new(PatternVal.new(_source_neuron_local_coords[0].x), PatternVal.new(_source_neuron_local_coords[0].y), PatternVal.new(_source_neuron_local_coords[0].z))
				var outgoing: PatternVector3 = PatternVector3.new(PatternVal.new(_destination_neuron_local_coords[0].x), PatternVal.new(_destination_neuron_local_coords[0].y), PatternVal.new(_destination_neuron_local_coords[0].z))
				morphology_name += "[%d,%d,%d]->[%d,%d,%d]\n" % [_source_neuron_local_coords[0].x, _source_neuron_local_coords[0].y, _source_neuron_local_coords[0].z, _destination_neuron_local_coords[0].x, _destination_neuron_local_coords[0].y, _destination_neuron_local_coords[0].z]
				pairs.append(PatternVector3Pairs.new(incoming, outgoing))
		morphology_name = morphology_name.left(16) # limit length
		while morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies:
			morphology_name += "2"
		var response: FeagiRequestOutput = await FeagiCore.requests.add_pattern_morphology(morphology_name, pairs)
		
		if !response.success:
			push_error("FEAGI: Failed to create morphology needed for quick connect!")
			close_window()
			return
		var new_morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name]
		FeagiCore.requests.append_default_mapping_between_corticals(_source, _destination, new_morphology)
	close_window()


func close_window():
	super()
	BV.BM.clear_all_selections()
	BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT)
