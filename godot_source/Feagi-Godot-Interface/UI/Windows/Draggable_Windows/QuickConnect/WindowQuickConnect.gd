extends DraggableWindow
class_name WindowQuickConnect

enum POSSIBLE_STATES {
	SOURCE,
	DESTINATION,
	MORPHOLOGY,
	IDLE
}

@export var style_incomplete: StyleBoxFlat
@export var style_waiting: StyleBoxFlat
@export var style_complete: StyleBoxFlat


var _step1_panel: PanelContainer
var _step2_panel: PanelContainer
var _step3_panel: PanelContainer
var _step1_label: Label
var _step2_label: Label
var _step3_label: Label
var _step3_info: HBoxContainer
var _step3_scroll: MorphologyScroll
var _step3_MorphologyView: SmartMorphologyView
var _step3_MorphologyDetails: MorphologyGenericDetails
var _step4_button: TextButton_Element

var _current_state: POSSIBLE_STATES = POSSIBLE_STATES.IDLE

var _source: CorticalArea = null
var _destination: CorticalArea = null
var _selected_morphology: Morphology = null

func _ready() -> void:
	_step1_panel = $VBoxContainer/step1
	_step2_panel = $VBoxContainer/step2
	_step3_panel = $VBoxContainer/step3
	_step1_label = $VBoxContainer/step1/step1/Label
	_step2_label = $VBoxContainer/step2/step2/Label
	_step3_label = $VBoxContainer/step3/step3/Label
	_step3_info = $VBoxContainer/step3/step3/MorphologyInfo
	_step3_scroll = $VBoxContainer/step3/step3/MorphologyInfo/MorphologyScroll
	_step3_MorphologyView = $VBoxContainer/step3/step3/MorphologyInfo/SmartMorphologyView
	_step4_button = $VBoxContainer/Establish
	
	FeagiEvents.user_selected_cortical_area.connect(on_user_select_cortical_area)
	
	_step1_panel.add_theme_stylebox_override("panel", style_incomplete)
	_step2_panel.add_theme_stylebox_override("panel", style_incomplete)
	_step3_panel.add_theme_stylebox_override("panel", style_incomplete)
	_step4_button.disabled = true

## Called from Window manager, to save previous position
func save_to_memory() -> Dictionary:
	return {
		"position": position,
	}

## Called from Window manager, to load previous position
func load_from_memory(previous_data: Dictionary) -> void:
	position = previous_data["position"]


func on_user_select_cortical_area(cortial_area: CorticalArea) -> void:
	match _current_state:
		POSSIBLE_STATES.SOURCE:
			_set_source(cortial_area)
		POSSIBLE_STATES.DESTINATION:
			_set_destination(cortial_area)
		_:
			return

func _setting_source() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Source Area...")
	_source = null
	_set_establish_button_availability()
	_step1_label.text = "Please Select A Source Area..."
	_step1_panel.add_theme_stylebox_override("panel", style_waiting)
	_current_state = POSSIBLE_STATES.SOURCE

func _setting_destination() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Destination Area...")
	_destination = null
	_set_establish_button_availability()
	_step2_label.text = "Please Select A Destination Area..."
	_step2_panel.add_theme_stylebox_override("panel", style_waiting)
	_current_state = POSSIBLE_STATES.DESTINATION

func _setting_morphology() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Morphology...")
	_selected_morphology = null
	_set_establish_button_availability()
	_step3_label.text = "Please Select A Morphology..."
	_step3_panel.add_theme_stylebox_override("panel", style_waiting)
	_current_state = POSSIBLE_STATES.MORPHOLOGY

func _set_source(cortical_area: CorticalArea) -> void:
	_source = cortical_area
	_step1_label.text = "Selected Source Area: " + cortical_area.name
	_step1_panel.add_theme_stylebox_override("panel", style_complete)
	_set_establish_button_availability()
	_current_state = POSSIBLE_STATES.IDLE

func _set_destination(cortical_area: CorticalArea) -> void:
	_destination = cortical_area
	_step2_label.text = "Selected Destination Area: " + cortical_area.name
	_step2_panel.add_theme_stylebox_override("panel", style_complete)
	_set_establish_button_availability()
	_current_state = POSSIBLE_STATES.IDLE

func _set_morphology(morphology: Morphology) -> void:
	_selected_morphology = morphology
	_step3_label.text = "Selected Morphology: " + morphology.name
	_step3_panel.add_theme_stylebox_override("panel", style_complete)
	_set_establish_button_availability()
	_current_state = POSSIBLE_STATES.IDLE

func _set_establish_button_availability():
	if !_source:
		_step4_button.disabled = true
	if !_destination:
		_step4_button.disabled = true
	if !_selected_morphology:
		_step4_button.disabled = true
	_step4_button.disabled = false

func establish_connection_button():
	print("UI: WINDOW: QUICKCONNECT: User Requesting quick connection...")
	FeagiRequests.request_default_mapping_between_corticals(_source, _destination, _selected_morphology)
