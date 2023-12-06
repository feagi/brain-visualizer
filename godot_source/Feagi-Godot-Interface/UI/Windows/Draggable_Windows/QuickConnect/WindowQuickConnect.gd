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

var current_state: POSSIBLE_STATES:
	get: return _current_state
	set(v):
		_update_current_state(v)

var _step1_panel: PanelContainer
var _step2_panel: PanelContainer
var _step3_panel: PanelContainer
var _step1_button: TextureButton
var _step2_button: TextureButton
var _step3_button: TextureButton
var _step1_label: Label
var _step2_label: Label
var _step3_label: Label
var _step3_info: PanelContainer
var _step3_scroll: MorphologyScroll
var _step3_MorphologyView: SmartMorphologyView
var _step3_MorphologyDetails: MorphologyGenericDetails
var _step4_button: TextButton_Element

var _current_state: POSSIBLE_STATES = POSSIBLE_STATES.IDLE
var _finished_selecting: bool = false

var _source: CorticalArea = null
var _destination: CorticalArea = null
var _selected_morphology: Morphology = null

func _ready() -> void:
	super()
	_step1_panel = $VBoxContainer/step1
	_step2_panel = $VBoxContainer/step2
	_step3_panel = $VBoxContainer/step3
	_step1_button = $VBoxContainer/step1/step1/TextureButton
	_step2_button = $VBoxContainer/step2/step2/TextureButton
	_step3_button = $VBoxContainer/step3/step3/HBoxContainer/TextureButton
	_step1_label = $VBoxContainer/step1/step1/Label
	_step2_label = $VBoxContainer/step2/step2/Label
	_step3_label = $VBoxContainer/step3/step3/HBoxContainer/Label
	_step3_info = $VBoxContainer/MorphologyInfoContainer
	_step3_scroll = $VBoxContainer/MorphologyInfoContainer/MorphologyInfo/MorphologyScroll
	_step3_MorphologyView = $VBoxContainer/MorphologyInfoContainer/MorphologyInfo/SmartMorphologyView
	_step3_MorphologyDetails = $VBoxContainer/MorphologyInfoContainer/MorphologyInfo/MorphologyGenericDetails
	_step4_button = $VBoxContainer/Establish
	
	FeagiEvents.user_selected_cortical_area.connect(on_user_select_cortical_area)
	
	_step1_panel.add_theme_stylebox_override("panel", style_incomplete)
	_step2_panel.add_theme_stylebox_override("panel", style_incomplete)
	_step3_panel.add_theme_stylebox_override("panel", style_incomplete)
	current_state = POSSIBLE_STATES.SOURCE

func on_user_select_cortical_area(cortial_area: CorticalArea) -> void:
	match _current_state:
		POSSIBLE_STATES.SOURCE:
			_set_source(cortial_area)
		POSSIBLE_STATES.DESTINATION:
			_set_destination(cortial_area)
		_:
			return

func establish_connection_button():
	print("UI: WINDOW: QUICKCONNECT: User Requesting quick connection...")

	# Make sure the cache has the current mapping state of the cortical to source area to append to
	FeagiRequests.request_add_default_mapping_between_corticals(_source, _destination, _selected_morphology)
	## TODO: This is technically a race condition, if a user clicks through the quick connect fast enough
	
	VisConfig.UI_manager.window_manager.force_close_window("quick_connect")

# State Machine
func _update_current_state(new_state: POSSIBLE_STATES) -> void:
	match new_state:
		POSSIBLE_STATES.IDLE:
			_toggle_add_buttons(true)
			_step4_button.disabled = false

		POSSIBLE_STATES.SOURCE:
			_toggle_add_buttons(false)
			_step4_button.disabled = true
			_setting_source()

		POSSIBLE_STATES.DESTINATION:
			_toggle_add_buttons(false)
			_step4_button.disabled = true
			_setting_destination()

		POSSIBLE_STATES.MORPHOLOGY:
			_toggle_add_buttons(false)
			_step4_button.disabled = true
			_setting_morphology()

		_:
			push_error("UI: WINDOWS: WindowQuickConnect in unknown state!")
	
	_current_state = new_state



func _setting_source() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Source Area...")
	_source = null
	_step1_label.text = "Please Select A Source Area..."
	_step1_panel.add_theme_stylebox_override("panel", style_waiting)

func _setting_destination() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Destination Area...")
	_destination = null
	_step2_label.text = "Please Select A Destination Area..."
	_step2_panel.add_theme_stylebox_override("panel", style_waiting)

func _setting_morphology() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Morphology...")
	_selected_morphology = null
	_step3_label.text = "Please Select A Morphology..."
	_step3_panel.add_theme_stylebox_override("panel", style_waiting)
	

func _set_source(cortical_area: CorticalArea) -> void:
	_source = cortical_area
	_step1_label.text = "Selected Source Area: [" + cortical_area.name + "]"
	_step1_panel.add_theme_stylebox_override("panel", style_complete)
	if !_finished_selecting:
		_step2_panel.visible = true
		current_state = POSSIBLE_STATES.DESTINATION
	else:
		current_state = POSSIBLE_STATES.IDLE


func _set_destination(cortical_area: CorticalArea) -> void:
	_destination = cortical_area
	_step2_label.text = "Selected Destination Area: [" + cortical_area.name + "]"
	_step2_panel.add_theme_stylebox_override("panel", style_complete)
	FeagiRequests.get_mapping_properties_between_two_areas(_source, _destination)
	if !_finished_selecting:
		_step3_panel.visible = true
		_step3_info.visible = true
		current_state = POSSIBLE_STATES.MORPHOLOGY
	else:
		current_state = POSSIBLE_STATES.IDLE


func _set_morphology(morphology: Morphology) -> void:
	_selected_morphology = morphology
	_step3_label.text = "Selected Morphology: " + morphology.name
	_step3_panel.add_theme_stylebox_override("panel", style_complete)
	_step3_MorphologyView.load_in_morphology(morphology)
	_step3_MorphologyDetails.load_in_morphology(morphology)
	_finished_selecting = true
	current_state = POSSIBLE_STATES.IDLE


func _toggle_add_buttons(is_enabled: bool):
	_step1_button.visible = is_enabled
	_step2_button.visible = is_enabled
	_step3_button.visible = is_enabled

func _set_completion_state():
	if _source == null:
		_finished_selecting = false
		_step4_button.visible = false
		return
	if _destination == null:
		_finished_selecting = false
		_step4_button.visible = false
		return
	if _selected_morphology == null:
		_finished_selecting = false
		_step4_button.visible = false
		return	
	_finished_selecting = true
	_step4_button.visible = true
		
