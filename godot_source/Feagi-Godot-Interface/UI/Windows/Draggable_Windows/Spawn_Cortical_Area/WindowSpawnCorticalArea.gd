extends BaseWindowPanel
class_name WindowSpawnCorticalArea

var _top_container: BoxContainer
var _selection: VBoxContainer
var _selection_options: PartSpawnCorticalAreaSelection
var _IOPU_definition: PartSpawnCorticalAreaIOPU
var _custom_definition: PartSpawnCorticalAreaCustom
var _memory_definition: PartSpawnCorticalAreaMemory
var _buttons: HBoxContainer
var _type_selected: BaseCorticalArea.CORTICAL_AREA_TYPE


func _ready() -> void:
	_top_container = $BoxContainer
	_selection = $BoxContainer/Selection
	_selection_options = $BoxContainer/Selection/options
	_IOPU_definition = $BoxContainer/Definition_IOPU
	_custom_definition = $BoxContainer/Definition_Custom
	_memory_definition = $BoxContainer/Definition_Memory
	_buttons = $BoxContainer/Buttons
	
	_selection_options.cortical_type_selected.connect(_step_2_set_details)


func setup() -> void:
	_setup_base_window("spawn_cortical")
	_step_1_pick_type()

func _step_1_pick_type() -> void:
	_IOPU_definition.visible = false
	_custom_definition.visible = false
	_memory_definition.visible = false
	_buttons.visible = false
	_selection.visible = true
	_top_container.size = Vector2(0,0)
	_set_header(BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN)

func _step_2_set_details(cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	_set_header(cortical_type)
	_type_selected = cortical_type
	_selection.visible = false
	
	## All cases that a preview needs to be closed
	var close_preview_signals: Array[Signal] = [
		$BoxContainer/Buttons/Back.pressed,
		close_window_requesed_no_arg
	]
	
	_IOPU_definition.visible = cortical_type in [BaseCorticalArea.CORTICAL_AREA_TYPE.IPU, BaseCorticalArea.CORTICAL_AREA_TYPE.OPU]
	_custom_definition.visible = cortical_type == BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM
	_memory_definition.visible = cortical_type == BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	_buttons.visible = true
	
	match(cortical_type):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			_IOPU_definition.cortical_type_selected(cortical_type, close_preview_signals)
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			_IOPU_definition.cortical_type_selected(cortical_type, close_preview_signals)
		BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			_custom_definition.cortical_type_selected(cortical_type, close_preview_signals)
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			_memory_definition.cortical_type_selected(cortical_type, close_preview_signals)
	

func _set_header(cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	var label: Label = $BoxContainer/header/Label
	var icon: TextureRect = $BoxContainer/header/icon
	if cortical_type == BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
		label.text = "Select Cortical Area Type:"
		icon.texture = null # clear texture
		return
	match(cortical_type):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			label.text = "Adding input Cortical Area"
			icon.texture = load("res://Feagi-Godot-Interface/UI/Resources/Icons/input.png")
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			label.text = "Adding output Cortical Area"
			icon.texture = load("res://Feagi-Godot-Interface/UI/Resources/Icons/output.png")
		BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			label.text = "Adding interconnect Cortical Area"
			icon.texture = load("res://Feagi-Godot-Interface/UI/Resources/Icons/interconnected.png")
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			label.text = "Adding memory Cortical Area"
			icon.texture = load("res://Feagi-Godot-Interface/UI/Resources/Icons/memory-game.png")
		
func _back_pressed() -> void:
	_step_1_pick_type()

func _user_requesting_exit() -> void:
	close_window()

func _user_requesing_creation() -> void:
	match(_type_selected):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			FeagiRequests.request_add_IOPU_cortical_area(
				_IOPU_definition.dropdown.get_selected_template(),
				_IOPU_definition.channel_count.value,
				_IOPU_definition.location.current_vector,
				false
			)
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			FeagiRequests.request_add_IOPU_cortical_area(
				_IOPU_definition.dropdown.get_selected_template(),
				_IOPU_definition.channel_count.value,
				_IOPU_definition.location.current_vector,
				false
			)
		BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			FeagiRequests.add_custom_cortical_area(
				_custom_definition.cortical_name.text,
				_custom_definition.location.current_vector,
				_custom_definition.dimensions.current_vector,
				false
				)
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			FeagiRequests.add_memory_cortical_area(
				_memory_definition.cortical_name.text,
				_memory_definition.location.current_vector,
				Vector3i(1,1,1),
				false
			)
	
	close_window()
