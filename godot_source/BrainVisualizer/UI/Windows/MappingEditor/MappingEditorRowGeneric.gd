extends HBoxContainer
class_name MappingEditorRowGeneric

var _morphologies: MorphologyDropDown
var _scalar: Vector3iField
var _PSP: FloatInput
var _inhibitory: ToggleButton
var _plasticity: ToggleButton
var _plasticity_constant: FloatInput
var _LTP_multiplier: FloatInput
var _LTD_multiplier: FloatInput
var _edit: TextureButton

func _ready() -> void:
	_morphologies = $Morphology_List
	_scalar = $Scalar
	_PSP = $PSP
	_inhibitory = $Inhibitory
	_plasticity = $Plasticity
	_plasticity_constant = $Plasticity_Constant
	_LTP_multiplier = $LTP_Multiplier
	_LTD_multiplier = $LTD_Multiplier
	_edit = $edit

func load_default_settings(default_morphology: BaseMorphology) -> void:
	if default_morphology != null:
		_morphologies.set_selected_morphology(default_morphology)

func load_mapping(mapping: SingleMappingDefinition) -> void:
	_morphologies.set_selected_morphology(mapping.morphology_used)
	_scalar.current_vector = mapping.scalar
	_PSP.current_float = abs(mapping.post_synaptic_current_multiplier)
	_inhibitory.set_toggle_no_signal(mapping.post_synaptic_current_multiplier < 0)
	_plasticity.set_toggle_no_signal(mapping.is_plastic)
	_LTP_multiplier.current_float = mapping.LTP_multiplier
	_LTD_multiplier.current_float = mapping.LTD_multiplier
	_on_user_toggle_plasticity(mapping.is_plastic)

func export_mapping() -> SingleMappingDefinition:
	var morphology_used: BaseMorphology = _morphologies.get_selected_morphology()
	var scalar: Vector3i = _scalar.current_vector
	var PSP: float = _PSP.current_float
	if _inhibitory.button_pressed:
		PSP = -PSP
	var is_plastic: bool = _plasticity.button_pressed
	var plasticity_constant: float = _plasticity_constant.current_float
	var LTP_multiplier: float = _LTP_multiplier.current_float
	var LTD_multiplier: float = _LTD_multiplier.current_float
	return SingleMappingDefinition.new(
		morphology_used,
		scalar,
		PSP,
		is_plastic,
		plasticity_constant,
		LTP_multiplier,
		LTD_multiplier
	)


func _on_user_toggle_plasticity(toggle_state: bool) -> void:
	_plasticity_constant.editable = toggle_state
	_LTP_multiplier.editable = toggle_state
	_LTD_multiplier.editable = toggle_state

func _on_mapping_delete_press() -> void:
	get_parent().queue_free()
