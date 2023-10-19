extends VBoxContainer
class_name VerticalCollapsible

const TRIANGLE_DOWN_NORMAL: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/Triangle_Down_S.png")
const TRIANGLE_DOWN_PRESSED: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/Triangle_Down_C.png")
const TRIANGLE_DOWN_HOVER: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/Triangle_Down_H.png")
const TRIANGLE_DOWN_DISABLED: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/Triangle_Down_D.png")
const TRIANGLE_RIGHT_NORMAL: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/Triangle_Right_S.png")
const TRIANGLE_RIGHT_PRESSED: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/Triangle_Right_C.png")
const TRIANGLE_RIGHT_HOVER: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/Triangle_Right_H.png")
const TRIANGLE_RIGHT_DISABLED: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/Triangle_Right_D.png")

## State collapsible seciton should be on start. No effect after
@export var start_open: bool = true
## prefab to spawn
@export var prefab_to_spawn: PackedScene
@export var section_text: StringName

## The actual node that is being toggled on and off
var collapsing_node: Control:
	get: return _collapsing_node

var section_title: StringName:
	get: return get_child(0).get_node("Section_Title").text
	set(v):
		get_child(0).get_node("Section_Title").text = v

## Whether the collapsible section is open (or collapsed)
var is_open: bool:
	get: return _is_open
	set(v):
		_toggle_button_texture(v)
		_toggle_collapsible_section(v)
		_is_open = v

var _is_open: bool
var _collapsing_button_toggle: TextureButton_Element
var _collapsing_node: Control

func setup():
	var hbox: HBoxContainer = get_child(0)
	hbox.get_node("Section_Title").text = section_text
	_collapsing_button_toggle = hbox.get_node("Collapsible_Toggle")
	_collapsing_node = prefab_to_spawn.instantiate()
	add_child(_collapsing_node)
	is_open = start_open
	_collapsing_button_toggle.pressed.connect(_toggle_button_pressed)

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

func _toggle_collapsible_section(is_opened: bool) -> void:
	_collapsing_node.visible = is_opened

func _toggle_button_pressed() -> void:
	is_open = !_is_open
