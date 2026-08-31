extends HBoxContainer
class_name MappingEditorRowGeneric
## Single editable row of an inter-cortical mapping rule. Owns a dropdown for the new
## three-valued plasticity model (Off / STDP / R-STDP) plus optional R-STDP-only fields
## (eligibility decay, reward source, punishment source). Backwards compatibility with
## the legacy plasticity_flag is preserved by [SingleMappingDefinition.to_FEAGI_JSON]
## which still emits plasticity_flag and only adds plasticity_mode/eligibility/areas
## when the row is configured for R-STDP.

# Indices match the OptionButton items in MappingEditorRowGeneric.tscn.
const _MODE_OFF: int = 0
const _MODE_STDP: int = 1
const _MODE_RSTDP: int = 2

# Mapping between dropdown indices and the FEAGI string enum used by the genome.
const _MODE_INDEX_TO_STRING: Array[String] = ["off", "stdp", "rstdp"]

var _restrictions: MappingRestrictionCorticalMorphology
var _defaults: MappingRestrictionDefault

var _morphologies: MorphologyDropDown
var _scalar: Vector3iField
var _PSP: FloatInput
var _synaptic_delay: IntInput
var _inhibitory: ToggleButton
var _gate_source: CorticalDropDown
var _plasticity_mode: OptionButton  # Off / STDP / R-STDP
var _plasticity_window: IntInput
var _plasticity_constant: FloatInput
var _LTP_multiplier: FloatInput
var _LTD_multiplier: FloatInput
var _eligibility_decay: IntInput
var _reward_source: CorticalDropDown
var _punishment_source: CorticalDropDown
var _edit: TextureButton

func _ready() -> void:
	_morphologies = $MappingDefinitionGroup/Morphology_List
	_scalar = $Scalar
	_PSP = $PSP
	_synaptic_delay = $Synaptic_Delay
	_inhibitory = $Inhibitory
	_gate_source = $Gate_Source_Area
	_plasticity_mode = $Plasticity_Mode
	_plasticity_window = $Plasticity_Window
	_plasticity_constant = $Plasticity_Constant
	_LTP_multiplier = $LTP_Multiplier
	_LTD_multiplier = $LTD_Multiplier
	_eligibility_decay = $Eligibility_Decay_Bursts
	_reward_source = $Reward_Source_Area
	_punishment_source = $Punishment_Source_Area
	_edit = $MappingDefinitionGroup/edit

	# Populate the plasticity-mode dropdown. We do this in code (rather than in the .tscn)
	# to match the convention used by the rest of the editor, where OptionButtons are
	# filled at runtime via add_item().
	if _plasticity_mode.item_count == 0:
		_plasticity_mode.add_item("Off", _MODE_OFF)
		_plasticity_mode.add_item("STDP", _MODE_STDP)
		_plasticity_mode.add_item("R-STDP", _MODE_RSTDP)
	_select_plasticity_mode(_MODE_OFF)

	_morphologies.user_selected_morphology.connect(_on_morphology_selected)

func load_settings(restrictions: MappingRestrictionCorticalMorphology, defaults: MappingRestrictionDefault) -> void:
	_restrictions = restrictions
	_defaults = defaults

	if restrictions != null:
		if restrictions.has_restricted_morphologies():
			_morphologies.overwrite_morphologies(restrictions.get_morphologies_restricted_to())
		if restrictions.has_disallowed_morphologies():
			for disallowed in restrictions.get_morphologies_disallowed():
				_morphologies.remove_morphology(disallowed)
		_scalar.editable = restrictions.allow_changing_scalar
		_PSP.editable = restrictions.allow_changing_PSP
		_synaptic_delay.editable = restrictions.allow_changing_PSP
		_inhibitory.disabled = !restrictions.allow_changing_inhibitory
		_plasticity_mode.disabled = !restrictions.allow_changing_plasticity
	else:
		_scalar.editable = true
		_PSP.editable = true
		_synaptic_delay.editable = true
		_inhibitory.disabled = false
		_plasticity_mode.disabled = false

	if defaults != null:
		_morphologies.set_selected_morphology(defaults.try_get_default_morphology())

	# Normal mappings default to Off. Associative-memory mappings require STDP or R-STDP.
	_select_plasticity_mode(_MODE_OFF)
	_apply_associative_plasticity_mode(_morphologies.get_selected_morphology())
	_apply_mode_field_state(_get_selected_plasticity_mode())

func load_mapping(mapping: SingleMappingDefinition) -> void:
	_morphologies.set_selected_morphology(mapping.morphology_used)
	_scalar.current_vector = mapping.scalar
	_PSP.current_float = absf(mapping.post_synaptic_current_multiplier)
	_synaptic_delay.current_int = mapping.synaptic_delay_bursts
	_inhibitory.set_toggle_no_signal(mapping.post_synaptic_current_multiplier < 0)
	_set_dropdown_to_area_id(_gate_source, mapping.gate_source_area)

	var mode_index: int = _resolve_mode_index_from_mapping(mapping)
	_select_plasticity_mode(mode_index)

	_plasticity_window.current_int = mapping.plasticity_window
	_plasticity_constant.current_float = mapping.plasticity_constant
	_LTP_multiplier.current_float = mapping.LTP_multiplier
	_LTD_multiplier.current_float = mapping.LTD_multiplier
	_eligibility_decay.current_int = mapping.eligibility_decay_bursts
	_set_dropdown_to_area_id(_reward_source, mapping.reward_source_area)
	_set_dropdown_to_area_id(_punishment_source, mapping.punishment_source_area)

	_apply_associative_plasticity_mode(mapping.morphology_used)
	_apply_mode_field_state(_get_selected_plasticity_mode())

func export_mapping() -> SingleMappingDefinition:
	var morphology_used: BaseMorphology = _morphologies.get_selected_morphology()
	var scalar: Vector3i = _scalar.current_vector
	var PSP: float = _PSP.current_float
	if _inhibitory.button_pressed:
		PSP = -PSP

	var mode_index: int = _get_selected_plasticity_mode()
	# associative_memory always requires a plastic mode. Preserve the user's explicit choice
	# between STDP and R-STDP, while treating an Off selection as STDP.
	if _is_associative_memory_morphology(morphology_used) and mode_index == _MODE_OFF:
		mode_index = _MODE_STDP

	var is_plastic: bool = mode_index != _MODE_OFF
	var plasticity_constant: float = _plasticity_constant.current_float
	var plasticity_window: int = _plasticity_window.current_int
	var LTP_multiplier: float = _LTP_multiplier.current_float
	var LTD_multiplier: float = _LTD_multiplier.current_float
	var delay_bursts: int = maxi(1, _synaptic_delay.current_int)

	# R-STDP-only fields. We only forward them when mode == R-STDP so STDP and Off rules
	# remain wire-compatible with consumers that have not learned about plasticity_mode yet.
	var mode_string: String = ""
	var eligibility_decay_bursts: int = 0
	var reward_id: String = ""
	var punishment_id: String = ""
	if mode_index == _MODE_RSTDP:
		mode_string = _MODE_INDEX_TO_STRING[_MODE_RSTDP]
		eligibility_decay_bursts = maxi(0, _eligibility_decay.current_int)
		reward_id = _get_dropdown_area_id(_reward_source)
		punishment_id = _get_dropdown_area_id(_punishment_source)
	elif mode_index == _MODE_STDP:
		# Emit the explicit "stdp" string when the user picks STDP from the dropdown so the
		# genome round-trips a value the user can recognize. Off intentionally leaves the
		# field empty so legacy consumers continue to read plasticity_flag=false.
		mode_string = _MODE_INDEX_TO_STRING[_MODE_STDP]

	var gate_id: String = _get_dropdown_area_id(_gate_source)

	return SingleMappingDefinition.new(
		morphology_used,
		scalar,
		PSP,
		is_plastic,
		plasticity_constant,
		LTP_multiplier,
		LTD_multiplier,
		plasticity_window,
		delay_bursts,
		mode_string,
		eligibility_decay_bursts,
		reward_id,
		punishment_id,
		gate_id,
	)

func _on_user_PSP(_value: float) -> void:
	# FloatInput updates its internal value on validation; this exists to satisfy the
	# scene-level signal connection.
	pass

## OptionButton.item_selected handler. Toggles edit-state of plasticity-related fields
## according to the new mode selection.
func _on_user_select_plasticity_mode(mode_index: int) -> void:
	_apply_mode_field_state(_plasticity_mode.get_item_id(mode_index))

func _on_morphology_selected(morphology: BaseMorphology) -> void:
	_apply_associative_plasticity_mode(morphology)
	_apply_mode_field_state(_get_selected_plasticity_mode())

## Keeps associative-memory mappings plastic without constraining STDP versus R-STDP.
func _apply_associative_plasticity_mode(morphology: BaseMorphology) -> void:
	if _is_associative_memory_morphology(morphology):
		_set_off_mode_visible(false)
		if _get_selected_plasticity_mode() == _MODE_OFF:
			_select_plasticity_mode(_MODE_STDP)
		if _restrictions:
			_plasticity_mode.disabled = !_restrictions.allow_changing_plasticity
		else:
			_plasticity_mode.disabled = false
	else:
		_set_off_mode_visible(true)
		if _restrictions:
			_plasticity_mode.disabled = !_restrictions.allow_changing_plasticity
		else:
			_plasticity_mode.disabled = false

func _is_associative_memory_morphology(morphology: BaseMorphology) -> bool:
	return morphology != null and morphology.name == &"associative_memory"

## Keeps Off available for normal mappings but removes it from associative-memory choices.
func _set_off_mode_visible(visible: bool) -> void:
	var selected_mode: int = _get_selected_plasticity_mode()
	if not visible and selected_mode == _MODE_OFF:
		selected_mode = _MODE_STDP
	_plasticity_mode.clear()
	if visible:
		_plasticity_mode.add_item("Off", _MODE_OFF)
	_plasticity_mode.add_item("STDP", _MODE_STDP)
	_plasticity_mode.add_item("R-STDP", _MODE_RSTDP)
	_select_plasticity_mode(selected_mode)

## Returns the stable mode ID, which differs from the option index when Off is omitted.
func _get_selected_plasticity_mode() -> int:
	return _plasticity_mode.get_selected_id()

## Selects a plasticity mode by its stable item ID.
func _select_plasticity_mode(mode: int) -> void:
	for item_index in _plasticity_mode.item_count:
		if _plasticity_mode.get_item_id(item_index) == mode:
			_plasticity_mode.select(item_index)
			return

## Centralised editability rules for plasticity-related fields, keyed off the dropdown
## selection. Honors mapping restrictions when present.
func _apply_mode_field_state(mode_index: int) -> void:
	var stdp_active: bool = mode_index != _MODE_OFF
	var rstdp_active: bool = mode_index == _MODE_RSTDP

	var allow_constants: bool = true
	if _restrictions:
		allow_constants = _restrictions.allow_changing_plasticity_constant

	# STDP knobs are usable for both STDP and R-STDP.
	_plasticity_window.editable = stdp_active and allow_constants
	_plasticity_constant.editable = stdp_active and allow_constants
	_LTP_multiplier.editable = stdp_active and allow_constants
	_LTD_multiplier.editable = stdp_active and allow_constants

	# R-STDP-only knobs.
	_eligibility_decay.editable = rstdp_active and allow_constants
	_reward_source.disabled = !rstdp_active
	_punishment_source.disabled = !rstdp_active

## Picks the dropdown index for the mapping. Priority:
##   1. explicit plasticity_mode string (off / stdp / rstdp)
##   2. presence of a reward/punishment source (treated as R-STDP)
##   3. legacy plasticity_flag (true => STDP, false => Off)
func _resolve_mode_index_from_mapping(mapping: SingleMappingDefinition) -> int:
	var explicit_mode: String = mapping.plasticity_mode.to_lower()
	if explicit_mode == "rstdp":
		return _MODE_RSTDP
	if explicit_mode == "stdp":
		return _MODE_STDP
	if explicit_mode == "off":
		return _MODE_OFF
	if mapping.has_reward_modulation:
		return _MODE_RSTDP
	if mapping.is_plastic:
		return _MODE_STDP
	return _MODE_OFF

## Selects the cortical area in [dropdown] matching [area_id], or clears the selection
## when [area_id] is empty. Falls back to deselect when the area is not in the cache.
func _set_dropdown_to_area_id(dropdown: CorticalDropDown, area_id: String) -> void:
	if dropdown == null:
		return
	if area_id == "":
		dropdown.deselect_all()
		return
	var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID(area_id)
	if area == null:
		dropdown.deselect_all()
		return
	dropdown.set_selected_cortical_area(area)

## Returns the cortical_ID of the area selected in [dropdown], or "" when nothing is selected.
func _get_dropdown_area_id(dropdown: CorticalDropDown) -> String:
	if dropdown == null:
		return ""
	var area: AbstractCorticalArea = dropdown.get_selected_cortical_area()
	if area == null:
		return ""
	return String(area.cortical_ID)

func _on_edit_pressed() -> void:
	var morphology: BaseMorphology = _morphologies.get_selected_morphology()
	if morphology != null:
		BV.WM.spawn_manager_morphology(morphology)

func _on_mapping_delete_press() -> void:
	get_parent().delete_this()
