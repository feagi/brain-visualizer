extends HBoxContainer
class_name Prefab_Mapping

var _morphologies: DropDown
var _scalar: Vector3iField
var _PSP: FloatInput
var _plasticity: Button
var _plasticity_constant: FloatInput
var _LTP_multiplier: FloatInput
var _LTD_multiplier: FloatInput


func _ready() -> void:
	_morphologies = $Morphology_List
	_scalar = $Scalar
	_PSP = $PSP
	_plasticity = $Plasticity
	_plasticity_constant = $Plasticity_Constant
	_LTP_multiplier = $LTP_Multiplier
	_LTD_multiplier = $LTD_Multiplier

func setup(data: Dictionary, _main_window) -> void:
	_morphologies.options = data["morphologies"]
	var _mapping_ref: MappingProperty = data["mapping"]
	_scalar.current_vector = _mapping_ref.scalar
	_PSP.current_float = _mapping_ref.post_synaptic_current_multiplier
	_plasticity.button_pressed = _mapping_ref.is_plastic
	_plasticity_constant.current_float = _mapping_ref.plasticity_constant
	_LTP_multiplier.current_float = _mapping_ref.LTP_multiplier
	_LTD_multiplier.current_float = _mapping_ref.LTD_multiplier
	_morphologies.set_option(_mapping_ref.morphology_used.name)
	_on_user_toggle_plasticity(_plasticity.button_pressed)

## Generate a [MappingProperty] from the given data in this scene
func generate_mapping_property() -> MappingProperty:
	var morphology_used: Morphology = FeagiCache.morphology_cache.available_morphologies[_morphologies.selected_item]
	var scalar: Vector3i = _scalar.current_vector
	var PSP: float = _PSP.current_float
	var is_plastic: bool = _plasticity.button_pressed
	var plasticity_constant: float = _plasticity_constant.current_float
	var LTP_multiplier: float = _LTP_multiplier.current_float
	var LTD_multiplier: float = _LTD_multiplier.current_float
	return MappingProperty.new(morphology_used, scalar, PSP, is_plastic, plasticity_constant, LTP_multiplier, LTD_multiplier)

func _on_user_toggle_plasticity(toggle_state: bool) -> void:
	_plasticity_constant.editable = toggle_state
	_LTP_multiplier.editable = toggle_state
	_LTD_multiplier.editable = toggle_state


func _on_delete_pressed() -> void:
	queue_free()
	if get_parent() is Window:
		# we are testing this individual scene, do not proceed
		print("Not Deleting Mapping due to testing individual scene")
		return

func _on_info_pressed() -> void:
	var morphology_used: Morphology = FeagiCache.morphology_cache.available_morphologies[_morphologies.selected_item]
	VisConfig.UI_manager.window_manager.spawn_manager_morphology(morphology_used)
