extends PanelContainer
class_name VerticalCollapsibleHiding

const TRIANGLE_DOWN_NORMAL: CompressedTexture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Down_S.png")
const TRIANGLE_DOWN_PRESSED: CompressedTexture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Down_C.png")
const TRIANGLE_DOWN_HOVER: CompressedTexture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Down_H.png")
const TRIANGLE_DOWN_DISABLED: CompressedTexture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Down_D.png")
const TRIANGLE_RIGHT_NORMAL: CompressedTexture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Right_S.png")
const TRIANGLE_RIGHT_PRESSED: CompressedTexture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Right_C.png")
const TRIANGLE_RIGHT_HOVER: CompressedTexture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Right_H.png")
const TRIANGLE_RIGHT_DISABLED: CompressedTexture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Right_D.png")

@export var start_open: bool = true
@export var section_text: StringName


var is_open: bool: ## Whether the collapsible section is open (or collapsed)
	get: return _is_open
	set(v):
		_toggle_button_texture(v)
		_toggle_collapsible_section(v)
		_is_open = v

var _collapsing_button_toggle: TextureButton
var _collapsing_section: PanelContainer
var _is_open: bool

# Called when the node enters the scene tree for the first time.
func _ready():
	($VerticalCollapsible/HBoxContainer/Section_Title as Label).text = section_text
	_collapsing_button_toggle = $VerticalCollapsible/HBoxContainer/Collapsible_Toggle
	_collapsing_section = $VerticalCollapsible/PanelContainer
	is_open = start_open

## Returns the first control in the collapsing section
func get_control() -> Control:
	return _collapsing_section.get_child(0)

func _toggle_collapsible_section(is_opened: bool) -> void:
	_collapsing_section.visible = is_opened

func _toggle_button_texture(is_opened: bool) -> void:
	if is_opened:
		_collapsing_button_toggle.texture_normal = TRIANGLE_DOWN_NORMAL
		_collapsing_button_toggle.texture_pressed = TRIANGLE_DOWN_PRESSED
		_collapsing_button_toggle.texture_hover = TRIANGLE_DOWN_HOVER
		_collapsing_button_toggle.texture_disabled = TRIANGLE_DOWN_DISABLED
	else:
		_collapsing_button_toggle.texture_normal = TRIANGLE_RIGHT_NORMAL
		_collapsing_button_toggle.texture_pressed = TRIANGLE_RIGHT_PRESSED
		_collapsing_button_toggle.texture_hover = TRIANGLE_RIGHT_HOVER
		_collapsing_button_toggle.texture_disabled = TRIANGLE_RIGHT_DISABLED

func _toggle_button_pressed() -> void:
	is_open = !_is_open
