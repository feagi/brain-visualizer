extends HBoxContainer
class_name MappingEditorRowGeneric

var _restrictions: MappingRestrictionCorticalMorphology
var _defaults: MappingRestrictionDefault

var _morphologies: MorphologyDropDown
var _scalar: Vector3iField
var _PSP: IntInput
var _inhibitory: ToggleButton
var _plasticity: ToggleButton
var _plasticity_window: IntInput
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
	_plasticity_window = $Plasticity_Window
	_plasticity_constant = $Plasticity_Constant
	_LTP_multiplier = $LTP_Multiplier
	_LTD_multiplier = $LTD_Multiplier
	_edit = $edit
	_morphologies.user_selected_morphology.connect(_on_morphology_selected)

func load_settings(restrictions: MappingRestrictionCorticalMorphology, defaults: MappingRestrictionDefault) -> void:
	_restrictions = restrictions
	_defaults = defaults
	
	# Add null checking for all restrictions method calls
	if restrictions != null:
		if restrictions.has_restricted_morphologies():
			_morphologies.overwrite_morphologies(restrictions.get_morphologies_restricted_to())
		if restrictions.has_disallowed_morphologies():
			for disallowed in restrictions.get_morphologies_disallowed():
				_morphologies.remove_morphology(disallowed)
		_scalar.editable = restrictions.allow_changing_scalar
		_PSP.editable = restrictions.allow_changing_PSP
		_inhibitory.disabled = !restrictions.allow_changing_inhibitory
		_plasticity.disabled = !restrictions.allow_changing_plasticity
	else:
		# Default behavior when no restrictions
		_scalar.editable = true
		_PSP.editable = true
		_inhibitory.disabled = false
		_plasticity.disabled = false
	
	# Set default morphology if available
	if defaults != null:
		_morphologies.set_selected_morphology(defaults.try_get_default_morphology())
	
	_plasticity_constant.editable = false # these 3 are false since originally plasticity is off
	_plasticity_window.editable = false
	_LTP_multiplier.editable = false
	_LTD_multiplier.editable = false

func load_mapping(mapping: SingleMappingDefinition) -> void:
	_morphologies.set_selected_morphology(mapping.morphology_used)
	_scalar.current_vector = mapping.scalar
	_PSP.current_int = abs(mapping.post_synaptic_current_multiplier)
	_inhibitory.set_toggle_no_signal(mapping.post_synaptic_current_multiplier < 0)
	_plasticity.set_toggle_no_signal(mapping.is_plastic)
	_plasticity_window.current_int = mapping.plasticity_window
	_plasticity_constant.current_float = mapping.plasticity_constant
	_LTP_multiplier.current_float = mapping.LTP_multiplier
	_LTD_multiplier.current_float = mapping.LTD_multiplier
	_apply_bi_directional_stdp_lock(mapping.morphology_used)
	
	if _restrictions:
		var is_plastic_now = _plasticity.button_pressed
		_plasticity_window.editable = is_plastic_now and _restrictions.allow_changing_plasticity_constant
		_plasticity_constant.editable = is_plastic_now and _restrictions.allow_changing_plasticity_constant
		_LTP_multiplier.editable = is_plastic_now and _restrictions.allow_changing_plasticity_constant
		_LTD_multiplier.editable = is_plastic_now and _restrictions.allow_changing_plasticity_constant
	else:
		_on_user_toggle_plasticity(_plasticity.button_pressed)

func export_mapping() -> SingleMappingDefinition:
	var morphology_used: BaseMorphology = _morphologies.get_selected_morphology()
	var scalar: Vector3i = _scalar.current_vector
	var PSP: int = _PSP.current_int
	if _inhibitory.button_pressed:
		PSP = -PSP
	var is_plastic: bool = _plasticity.button_pressed
	if _is_bi_directional_stdp_morphology(morphology_used):
		is_plastic = true
	var plasticity_constant: float = _plasticity_constant.current_float
	var plasticity_window: int = _plasticity_window.current_int
	var LTP_multiplier: float = _LTP_multiplier.current_float
	var LTD_multiplier: float = _LTD_multiplier.current_float
	return SingleMappingDefinition.new(
		morphology_used,
		scalar,
		PSP,
		is_plastic,
		plasticity_constant,
		LTP_multiplier,
		LTD_multiplier,
		plasticity_window
	)

func _on_user_PSP(_value: Variant) -> void:
	# IntInput updates its internal value on validation; no extra handling needed.
	# This exists to satisfy the connected signal in the scene.
	pass

func _on_user_toggle_plasticity(toggle_state: bool) -> void:
	_plasticity_window.editable = toggle_state
	_plasticity_constant.editable = toggle_state
	_LTP_multiplier.editable = toggle_state
	_LTD_multiplier.editable = toggle_state

func _on_morphology_selected(morphology: BaseMorphology) -> void:
	_apply_bi_directional_stdp_lock(morphology)
	if _restrictions:
		var is_plastic_now = _plasticity.button_pressed
		_plasticity_window.editable = is_plastic_now and _restrictions.allow_changing_plasticity_constant
		_plasticity_constant.editable = is_plastic_now and _restrictions.allow_changing_plasticity_constant
		_LTP_multiplier.editable = is_plastic_now and _restrictions.allow_changing_plasticity_constant
		_LTD_multiplier.editable = is_plastic_now and _restrictions.allow_changing_plasticity_constant
	else:
		_on_user_toggle_plasticity(_plasticity.button_pressed)

func _apply_bi_directional_stdp_lock(morphology: BaseMorphology) -> void:
	if _is_bi_directional_stdp_morphology(morphology):
		_plasticity.set_toggle_no_signal(true)
		_plasticity.disabled = true
	else:
		if _restrictions:
			_plasticity.disabled = !_restrictions.allow_changing_plasticity
		else:
			_plasticity.disabled = false

func _is_bi_directional_stdp_morphology(morphology: BaseMorphology) -> bool:
	# associative_memory is the morphology ID for bi-directional STDP
	return morphology != null and morphology.name == &"associative_memory"

func _on_edit_pressed() -> void:
	var morphology: BaseMorphology = _morphologies.get_selected_morphology()
	if morphology != null:
		BV.WM.spawn_manager_morphology(morphology)

func _on_mapping_delete_press() -> void:
	get_parent().delete_this()

