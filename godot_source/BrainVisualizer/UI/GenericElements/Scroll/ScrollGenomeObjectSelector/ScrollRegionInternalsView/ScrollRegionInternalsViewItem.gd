extends BoxContainer
class_name ScrollRegionInternalsViewItem

const PATH_CORTICAL_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/top_bar_cortical_area.png"
const PATH_REGION_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/architecture.png"

signal checkbox_clicked(object: GenomeObject, is_toggled_on: bool)
signal background_clicked(object: GenomeObject)

var target: GenomeObject:
	get: return _target

var _target: GenomeObject

var _button: PanelContainerButton
var _name: Label
var _icon: TextureRect
var _arrow: TextureRect
var _checkbox: CheckBox
var _radio_button_group: ButtonGroup


func _ready():
	_button = $PanelContainerButton
	_name = $PanelContainerButton/HBoxContainer/Name
	_icon = $PanelContainerButton/HBoxContainer/Icon
	_arrow = $PanelContainerButton/HBoxContainer/Arrow
	_checkbox = $PanelContainerButton/HBoxContainer/VBoxContainer/CheckButton

#NOTE: Dont handle response to deletions here, that will be handled by the [ScrollGenomeObjectSelector]

func setup_cortical_area(cortical_area: AbstractCorticalArea) -> void:
	_target = cortical_area
	_arrow.visible = false
	_icon.texture = load(PATH_CORTICAL_ICON)
	_updated_name(cortical_area.friendly_name)
	cortical_area.friendly_name_updated.connect(_updated_name)
	name = cortical_area.cortical_ID

func setup_region(region: BrainRegion) -> void:
	_target = region
	_icon.texture = load(PATH_REGION_ICON)
	_updated_name(region.friendly_name)
	region.friendly_name_updated.connect(_updated_name)
	name = region.region_ID

func set_to_radio_button_mode() -> void:
	_radio_button_group = ButtonGroup.new()
	_checkbox.button_group = _radio_button_group

func set_checkbox_check(is_checked: bool) -> void:
	_checkbox.set_pressed_no_signal(is_checked)

func disable_background_button(is_disabled: bool) -> void:
	_button.disabled = is_disabled

func disable_checkbox_button(is_disabled: bool) -> void:
	_checkbox.disabled = is_disabled

func hide_checkbox(hidden: bool) -> void:
	_checkbox.visible = !hidden

func _checkbox_toggled(is_on: bool) -> void:
	checkbox_clicked.emit(_target, is_on)

func _background_pressed() -> void:
	background_clicked.emit(_target)

func _updated_name(text: StringName) -> void:
	_name.text = text

