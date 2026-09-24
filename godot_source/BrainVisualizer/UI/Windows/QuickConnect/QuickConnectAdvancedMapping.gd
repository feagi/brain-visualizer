extends VBoxContainer
class_name QuickConnectAdvancedMapping
## Compact mapping-parameter form for Quick Connect.
## Hidden fields stay at the selected rule's defaults. Reward-modulated plasticity stays in the mapping editor.

signal layout_changed()

const _PLASTICITY_MODE_STDP: String = "stdp"
const _ASSOCIATIVE_MEMORY_NAME: StringName = &"associative_memory"
const _DEFAULT_SCALAR: Vector3i = Vector3i(1, 1, 1)

const _ROWS: NodePath = ^"AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows"

var _section: VerticalCollapsibleHiding
var _plasticity_rows: Control
var _psp: FloatInput
var _inhibitory: ToggleButton
var _synaptic_delay: IntInput
var _plasticity: ToggleButton
var _plasticity_constant: FloatInput
var _plasticity_window: IntInput
var _ltp_multiplier: FloatInput
var _ltd_multiplier: FloatInput
var _loaded_morphology_name: StringName = &""
var _associative_memory: bool = false


func _ready() -> void:
	_section = $AdvancedSection
	var title_label: Label = _section.get_node("VerticalCollapsible/HBoxContainer/Section_Title")
	title_label.text = "Advanced"
	title_label.theme_type_variation = &"Label_Header"
	var body: CanvasItem = _section.get_node("VerticalCollapsible/PanelContainer")
	body.visibility_changed.connect(func() -> void: layout_changed.emit())
	_plasticity_rows = get_node(NodePath(str(_ROWS) + "/PlasticityRows"))
	_psp = get_node(NodePath(str(_ROWS) + "/Primary/PSP"))
	_inhibitory = get_node(NodePath(str(_ROWS) + "/Primary/Inhibitory"))
	_synaptic_delay = get_node(NodePath(str(_ROWS) + "/Primary/SynapticDelay"))
	_plasticity = get_node(NodePath(str(_ROWS) + "/Primary/Plasticity"))
	_plasticity_constant = get_node(NodePath(str(_ROWS) + "/PlasticityRows/PlasticityConstant"))
	_plasticity_window = get_node(NodePath(str(_ROWS) + "/PlasticityRows/PlasticityWindow"))
	_ltp_multiplier = get_node(NodePath(str(_ROWS) + "/PlasticityRows/LTP"))
	_ltd_multiplier = get_node(NodePath(str(_ROWS) + "/PlasticityRows/LTD"))
	_plasticity.toggled.connect(_on_plasticity_toggled)
	_apply_toggle_theme_size(_inhibitory)
	_apply_toggle_theme_size(_plasticity)
	if BV != null and BV.UI != null and not BV.UI.theme_changed.is_connected(_on_ui_theme_changed):
		BV.UI.theme_changed.connect(_on_ui_theme_changed)
	_refresh_plasticity_rows()


func _on_ui_theme_changed(_theme: Theme) -> void:
	_apply_toggle_theme_size(_inhibitory)
	_apply_toggle_theme_size(_plasticity)


## Uses the loaded theme's ToggleButton size so the switch stays visible at every UI scale.
func _apply_toggle_theme_size(toggle: ToggleButton) -> void:
	if BV == null or BV.UI == null:
		return
	var theme_size: Vector2 = BV.UI.get_minimum_size_from_loaded_theme(&"ToggleButton")
	if theme_size.x <= 0.0 or theme_size.y <= 0.0:
		return
	toggle.enable_autoscaling_with_theme = false
	toggle.custom_minimum_size = theme_size


## True when the section is expanded and these values should be sent instead of mapping defaults.
func is_advanced_enabled() -> bool:
	return _section.is_open


## Opens or closes the Advanced section.
func set_advanced_enabled(enabled: bool) -> void:
	_section.is_open = enabled
	_refresh_plasticity_rows()
	layout_changed.emit()


## Fills the fields from the rule's default mapping. Repeating the same rule keeps user edits.
func load_for_morphology(morphology: BaseMorphology) -> void:
	if morphology == null:
		return
	if _loaded_morphology_name == morphology.name:
		return
	_loaded_morphology_name = morphology.name
	_associative_memory = morphology.name == _ASSOCIATIVE_MEMORY_NAME
	var defaults: SingleMappingDefinition = SingleMappingDefinition.create_default_mapping(morphology)
	_psp.current_float = absf(defaults.post_synaptic_current_multiplier)
	_inhibitory.set_toggle_no_signal(defaults.post_synaptic_current_multiplier < 0.0)
	_synaptic_delay.current_int = defaults.synaptic_delay_bursts
	_plasticity.set_toggle_no_signal(defaults.is_plastic or _associative_memory)
	_plasticity.disabled = _associative_memory
	_plasticity_constant.current_float = defaults.plasticity_constant
	_plasticity_window.current_int = defaults.plasticity_window
	_ltp_multiplier.current_float = defaults.LTP_multiplier
	_ltd_multiplier.current_float = defaults.LTD_multiplier
	_refresh_plasticity_rows()


## Disables fields the pair is not allowed to change. Associative memory stays plastic.
func apply_restrictions(restrictions: MappingRestrictionCorticalMorphology) -> void:
	var allow_psp: bool = true
	var allow_inhibitory: bool = true
	var allow_plasticity: bool = true
	var allow_constant: bool = true
	var allow_ltp: bool = true
	var allow_ltd: bool = true
	if restrictions != null:
		allow_psp = restrictions.allow_changing_PSP
		allow_inhibitory = restrictions.allow_changing_inhibitory
		allow_plasticity = restrictions.allow_changing_plasticity
		allow_constant = restrictions.allow_changing_plasticity_constant
		allow_ltp = restrictions.allow_changing_LTP
		allow_ltd = restrictions.allow_changing_LTD
	_psp.editable = allow_psp
	_synaptic_delay.editable = allow_psp
	_inhibitory.disabled = not allow_inhibitory
	_plasticity.disabled = _associative_memory or not allow_plasticity
	var plasticity_on: bool = _plasticity.button_pressed
	_plasticity_constant.editable = plasticity_on and allow_constant
	_plasticity_window.editable = plasticity_on and allow_constant
	_ltp_multiplier.editable = plasticity_on and allow_ltp
	_ltd_multiplier.editable = plasticity_on and allow_ltd


## Builds one mapping for the selected connectivity rule. Scalar stays at the default identity scale.
func export_mapping(morphology: BaseMorphology) -> SingleMappingDefinition:
	if morphology == null:
		return null
	var psp: float = absf(_psp.current_float)
	if _inhibitory.button_pressed:
		psp = -psp
	var plastic: bool = _plasticity.button_pressed or morphology.name == _ASSOCIATIVE_MEMORY_NAME
	var mode: String = _PLASTICITY_MODE_STDP if plastic else ""
	return SingleMappingDefinition.new(
		morphology,
		_DEFAULT_SCALAR,
		psp,
		plastic,
		_plasticity_constant.current_float,
		_ltp_multiplier.current_float,
		_ltd_multiplier.current_float,
		_plasticity_window.current_int,
		maxi(1, _synaptic_delay.current_int),
		mode,
	)


func _on_plasticity_toggled(pressed: bool) -> void:
	if _associative_memory and not pressed:
		_plasticity.set_toggle_no_signal(true)
	_refresh_plasticity_rows()
	layout_changed.emit()


func _refresh_plasticity_rows() -> void:
	_plasticity_rows.visible = _plasticity.button_pressed
