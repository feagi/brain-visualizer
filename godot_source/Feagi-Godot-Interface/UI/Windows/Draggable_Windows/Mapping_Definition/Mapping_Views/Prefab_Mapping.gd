extends HBoxContainer
class_name Prefab_Mapping

signal mapping_to_be_deleted()

var _morphologies: MorphologyDropDown
var _scalar: Vector3iField
var _PSP: FloatInput
var _plasticity: Button
var _plasticity_constant: FloatInput
var _LTP_multiplier: FloatInput
var _LTD_multiplier: FloatInput
var _edit: TextureButton


func _ready() -> void:
	_morphologies = $Morphology_List
	_scalar = $Scalar
	_PSP = $PSP
	_plasticity = $BoxContainer/Plasticity
	_plasticity_constant = $Plasticity_Constant
	_LTP_multiplier = $LTP_Multiplier
	_LTD_multiplier = $LTD_Multiplier
	_edit = $edit
	_morphologies.user_selected_morphology.connect(_on_user_change_morphology)

func setup(data: Dictionary, _main_window) -> void:
	var _mapping_ref: MappingProperty = data["mapping"]
	_scalar.current_vector = _mapping_ref.scalar
	_PSP.current_float = _mapping_ref.post_synaptic_current_multiplier
	_plasticity.button_pressed = _mapping_ref.is_plastic
	_plasticity_constant.current_float = _mapping_ref.plasticity_constant
	_LTP_multiplier.current_float = _mapping_ref.LTP_multiplier
	_LTD_multiplier.current_float = _mapping_ref.LTD_multiplier
	_on_user_toggle_plasticity(_plasticity.button_pressed)
	_on_user_change_morphology(_mapping_ref.morphology_used)
	_edit.disabled = !_mapping_ref.morphology_used.is_user_editable
	if "simple" in data.keys():
		_toggle_show_full_editing(false)
	if "allowed_morphologies" in data.keys():
		_morphologies.overwrite_morphologies(data["allowed_morphologies"])
	_morphologies.set_selected_morphology(_mapping_ref.morphology_used)

## Generate a [MappingProperty] from the given data in this scene
func generate_mapping_property() -> MappingProperty:
	var morphology_used: Morphology = _morphologies.get_selected_morphology()
	var scalar: Vector3i = _scalar.current_vector
	var PSP: float = _PSP.current_float
	var is_plastic: bool = _plasticity.button_pressed
	var plasticity_constant: float = _plasticity_constant.current_float
	var LTP_multiplier: float = _LTP_multiplier.current_float
	var LTD_multiplier: float = _LTD_multiplier.current_float
	return MappingProperty.new(morphology_used, scalar, PSP, is_plastic, plasticity_constant, LTP_multiplier, LTD_multiplier)

func _on_user_change_morphology(morphology: Morphology) -> void:
	_scalar.editable = morphology.is_user_editable
	_PSP.editable = morphology.is_user_editable
	_plasticity.disabled = !morphology.is_user_editable
	_on_user_toggle_plasticity(_plasticity.button_pressed and morphology.is_user_editable) #reuse this function

func _toggle_show_full_editing(full_editing: bool) -> void:
	_scalar.visible = full_editing
	_PSP.visible = full_editing
	_plasticity.visible = full_editing
	_plasticity_constant.visible = full_editing
	_LTP_multiplier.visible = full_editing
	_LTD_multiplier.visible = full_editing
	size = Vector2(0,0)

func _on_user_toggle_plasticity(toggle_state: bool) -> void:
	_plasticity_constant.editable = toggle_state
	_LTP_multiplier.editable = toggle_state
	_LTD_multiplier.editable = toggle_state

func _on_delete_pressed() -> void:
	get_parent().remove_child(self) # Cursed
	mapping_to_be_deleted.emit()
	queue_free()

func _on_info_pressed() -> void:
	var morphology_used: Morphology = _morphologies.get_selected_morphology()
	if morphology_used is NullMorphology:
		#TODO
		return
	VisConfig.UI_manager.window_manager.spawn_manager_morphology(morphology_used)
