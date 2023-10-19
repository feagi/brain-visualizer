extends GrowingPanel
class_name TopBar

var _refresh_rate_field: FloatInput
var _neuronal_circuits_add_button: TextureButton_Element
var _cortical_areas_view_button: TextureButton_Element
var _cortical_area_add_button: TextureButton_Element
var _cortical_area_connect_button: TextureButton_Element
var _neuron_morphology_add_button: TextureButton_Element
var _neuron_morphology_settings_button: TextureButton_Element
var _view_toggle_button: TextureButton_Element
var _view_toggle_label: Label
var _tutorial_button: TextureButton_Element
var _state_indicator: StateIndicator

var localize_refresh_rate: StringName
var localize_neuronal_cirtcuits: StringName
var localize_cortical_areas: StringName
var localize_neuron_morphologies: StringName
var localize_toggle_mode: Array[StringName]
var localize_tutorials: StringName


func _ready():
	super._ready()
	var _h_container: HBoxContainer = get_child(0)
	_refresh_rate_field = _h_container.get_node("RR_Float")
	_neuronal_circuits_add_button = _h_container.get_node("NC_Button")
	_cortical_areas_view_button = _h_container.get_node("CAView_Button")
	_cortical_area_add_button = _h_container.get_node("CAAdd_Button")
	_cortical_area_connect_button = _h_container.get_node("CAConnect_Button")
	_neuron_morphology_add_button = _h_container.get_node("NMAdd_Button")
	_neuron_morphology_settings_button = _h_container.get_node("NMSettings_Button")
	_view_toggle_button = _h_container.get_node("Mode_Button")
	_view_toggle_label = _h_container.get_node("Mode_Label")
	_tutorial_button = _h_container.get_node("TU_Button")
	_state_indicator = _h_container.get_node("StateIndicator")

	# from FEAGI
	FeagiCacheEvents.delay_between_bursts_updated.connect(_FEAGI_on_burst_delay_change)
	FeagiEvents.retrieved_latest_FEAGI_health.connect(_state_indicator.set_health_states)


	# from user
	_refresh_rate_field.float_confirmed.connect(_user_on_burst_delay_change)

func _FEAGI_on_burst_delay_change(new_delay_between_bursts_seconds: float) -> void:
	_refresh_rate_field.external_update_float( 1.0 / new_delay_between_bursts_seconds)

func _user_on_burst_delay_change(new_delay_between_bursts_seconds: float) -> void:
	FeagiRequests.set_delay_between_bursts(1.0 / new_delay_between_bursts_seconds)

# Attached to UIManager Mode change signal through root TSCN
func _mode_changed(new_mode: UIManager.MODE) -> void:
	match(new_mode):
		UIManager.MODE.CIRCUIT_BUILDER:
			$HBoxContainer/Mode_Button.texture_normal= load("res://Feagi-Godot-Interface/UI/Resources/Icons/Brain_Visualizer_S.png")
			$HBoxContainer/Mode_Button.texture_pressed= load("res://Feagi-Godot-Interface/UI/Resources/Icons/Brain_Visualizer_C.png")
			$HBoxContainer/Mode_Button.texture_hover= load("res://Feagi-Godot-Interface/UI/Resources/Icons/Brain_Visualizer_H.png")
			$HBoxContainer/Mode_Button.texture_disabled= load("res://Feagi-Godot-Interface/UI/Resources/Icons/Brain_Visualizer_D.png")
		UIManager.MODE.VISUALIZER_3D:
			$HBoxContainer/Mode_Button.texture_normal= load("res://Feagi-Godot-Interface/UI/Resources/Icons/Circuit_Builder_S.png")
			$HBoxContainer/Mode_Button.texture_pressed= load("res://Feagi-Godot-Interface/UI/Resources/Icons/Circuit_Builder_C.png")
			$HBoxContainer/Mode_Button.texture_hover= load("res://Feagi-Godot-Interface/UI/Resources/Icons/Circuit_Builder_H.png")
			$HBoxContainer/Mode_Button.texture_disabled= load("res://Feagi-Godot-Interface/UI/Resources/Icons/Circuit_Builder_D.png")
