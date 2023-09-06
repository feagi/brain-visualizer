extends HBoxContainer
class_name Prefab_Mapping

var _morphologies: DropDown
var _scalar: Vector3iField
var _PSP: FloatInput
var _plasticity: Button
var _plasticity_constant: FloatInput
var _LTP_multiplier: FloatInput
var _LTD_multiplier: FloatInput
var _mappings_ref: MappingProperties
var _mapping_ref: MappingProperty


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
	_mapping_ref = data["mapping"]
	_mappings_ref =data["mappings"]
	_scalar.current_vector = _mapping_ref.scalar
	_PSP.current_float = _mapping_ref.post_synaptic_current_multiplier
	_plasticity.button_pressed = _mapping_ref.is_plastic
	_plasticity_constant.current_float = _mapping_ref.plasticity_multiplier
	_LTP_multiplier.current_float = _mapping_ref.LTP_multiplier
	_LTD_multiplier.current_float = _mapping_ref.LTD_multiplier
	_morphologies.set_option(_mapping_ref.morphology_used.name)
	_on_user_toggle_plasticity(_plasticity.button_pressed)

# updating private members externally is bad practice. TODO address this better

func _on_user_set_morphology(_index, morphology_name: StringName) -> void:
	if morphology_name not in FeagiCache.morphology_cache.available_morphologies.keys():
		push_warning("Unable to set to uncached morphology!")
		_morphologies.select(-1)
		return
	_mapping_ref._morphology_used = FeagiCache.morphology_cache[morphology_name]

func _on_user_toggle_plasticity(toggle_state: bool) -> void:
	if !get_parent() is Window:
		_mapping_ref._plasticity_flag = toggle_state
	_plasticity_constant.editable = toggle_state
	_LTP_multiplier.editable = toggle_state
	_LTD_multiplier.editable = toggle_state

func _on_user_scalar(input: Vector3i) -> void:
	_mapping_ref._scalar = input

func _on_user_PSP(input: float) -> void:
	_mapping_ref._post_synaptic_current_multiplier = input

func _on_user_plasticity_constant(input: float) -> void:
	_mapping_ref._plasticity_multiplier = input

func _on_user_LTP_multiplier(input: float) -> void:
	_mapping_ref._LTP_multiplier = input

func _on_user_LTD_multiplier(input: float) -> void:
	_mapping_ref._LTD_multiplier = input

func _on_delete_pressed() -> void:
	queue_free()
	if get_parent() is Window:
		# we are testing this individual scene, do not proceed
		print("Not Deleting Mapping due to testing individual scene")
		return
	_mappings_ref.remove_mapping(get_index())

func _on_info_pressed() -> void:
	var morphology_used: Morphology = FeagiCache.morphology_cache.available_morphologies[_morphologies.selected_item]
	VisConfig.window_manager.spawn_manager_morphology(morphology_used)
