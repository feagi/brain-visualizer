extends VBoxContainer
class_name VerticalCollapsible

const TRIANGLE_DOWN: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/triangle_down.png")
const TRIANGLE_LEFT: CompressedTexture2D = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/triangle_left.png")

## State collapsible seciton should be on start. No effect after
@export var start_open: bool = true
## prefab to spawn
@export var prefab_to_spawn: PackedScene
@export var section_text: StringName

## The actual node that is being toggled on and off
var collapsing_node: Control:
	get: return _collapsing_node

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
		_collapsing_button_toggle.texture_normal = TRIANGLE_DOWN
	else:
		_collapsing_button_toggle.texture_normal = TRIANGLE_LEFT

func _toggle_collapsible_section(is_opened: bool) -> void:
	_collapsing_node.visible = is_opened

func _toggle_button_pressed() -> void:
	is_open = !_is_open
