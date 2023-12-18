extends HBoxContainer
class_name InterCorticalNodeTerminal
## Terminal below cortical area that is specific for a specific connection

const TEX_PLASTIC: Texture = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/cb-port-plastic.png")
const TEX_INPLASTIC: Texture = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/cb-port-non-plastic.png")

signal terminal_moved()

enum TYPE {
	INPUT,
	OUTPUT
}

var terminal_type: TYPE:
	get: return _terminal_type
var connected_area: BaseCorticalArea:
	get: return _connected_area
var representing_area: BaseCorticalArea:
	get: return _parent_node.cortical_area_ref
var cortical_node: CorticalNode:
	get: return _parent_node

var _terminal_type: TYPE ## The type of terminal
var _input_point: TerminalPortTexture
var _output_point: TerminalPortTexture
var _connected_area: BaseCorticalArea
var _parent_node: CorticalNode
var _cortical_label: Button

func _ready() -> void:
	set_notify_local_transform(true)
	_cortical_label = $Label
	_input_point = $input
	_output_point = $output

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		terminal_moved.emit()

func setup(connecting_area: BaseCorticalArea, type_terminal: TYPE, is_plastic: bool) -> void:
	_parent_node = get_parent()
	_connected_area = connecting_area
	_terminal_type = type_terminal
	
	_cortical_label.text = _connected_area.name
	name = _connected_area.cortical_ID
	_connected_area.name_updated.connect(_cortical_name_update)
	set_port_elastic(is_plastic)
	match type_terminal:
		TYPE.INPUT:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_cortical_label.tooltip_text = "Afferent Connection"
			_input_point.visible = true
		TYPE.OUTPUT:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_cortical_label.tooltip_text = "Efferent Connection"
			_output_point.visible = true
		_:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
			push_error("UI: GRAPH: Unknown Terminal Type")

## Set port icon by elastic property. Called from [InterCorticalConnection]
func set_port_elastic(is_plastic: bool) -> void:
		match _terminal_type:
			TYPE.INPUT:
				if is_plastic:
					_input_point.texture = TEX_PLASTIC
				else:
					_input_point.texture = TEX_INPLASTIC
			TYPE.OUTPUT:
				if is_plastic:
					_output_point.texture = TEX_PLASTIC
				else:
					_output_point.texture = TEX_INPLASTIC

## Get reference to child [TerminalPortTexture]
func get_port_reference() -> TerminalPortTexture:
	if _terminal_type == TYPE.INPUT:
		return _input_point
	else:
		return _output_point

## Get center point of the input terminal
func get_input_location() -> Vector2:
	return Vector2(_parent_node.position_offset) + Vector2(position) + Vector2(_input_point.position) + (_input_point.size / 2.0)

## Get center point of the output terminal
func get_output_location() -> Vector2:
	return Vector2(_parent_node.position_offset) + Vector2(position) + Vector2(_output_point.position) + (_output_point.size / 2.0)

func _cortical_name_update(new_name: String, _area: BaseCorticalArea) -> void:
	_cortical_label.text = new_name

#TODO have the button send you to the cortical Area
