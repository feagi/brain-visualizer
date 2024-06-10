extends BoxContainer
class_name ScrollRegionInternalsViewItem

const PATH_CORTICAL_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/top_bar_cortical_area.png"
const PATH_REGION_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/architecture.png"

signal user_clicked(object: GenomeObject)

var _target: GenomeObject

var _button: PanelContainerButton
var _name: Label
var _icon: TextureRect
var _arrow: TextureRect


func _ready():
	_button = $PanelContainerButton
	_name = $PanelContainerButton/HBoxContainer/Name
	_icon = $PanelContainerButton/HBoxContainer/Icon
	_arrow = $PanelContainerButton/HBoxContainer/Arrow
	_button.pressed.connect(_button_pressed)

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

func _button_pressed() -> void:
	user_clicked.emit(_target)

func _updated_name(text: StringName) -> void:
	_name.text = text
