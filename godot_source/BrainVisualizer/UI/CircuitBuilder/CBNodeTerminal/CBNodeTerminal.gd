extends HBoxContainer
class_name CBNodeTerminal

signal terminal_moved(CB_offset: Vector2)

enum TYPE {
	INPUT,
	OUTPUT,
	RECURSIVE
}

var terminal_type: TYPE:
	get: return _terminal_type

var _terminal_type: TYPE ## The type of terminal

var _tex_input: TextureRect
var _tex_output: TextureRect
var _tex_recursive: TextureRect
var _button: Button


func setup(terminal_type_: TYPE, terminal_text: StringName):
	_tex_input = $input
	_tex_output = $output
	_tex_recursive = $recurse
	_button = $Button
	
	_terminal_type = terminal_type_
	update_text(terminal_text)
	match(_terminal_type):
		TYPE.RECURSIVE:
			_tex_recursive.visible = true
		TYPE.INPUT:
			_tex_input.visible = true
		TYPE.OUTPUT:
			_tex_output.visible = true


func update_text(new_text: StringName) -> void:
	_button.text = new_text

