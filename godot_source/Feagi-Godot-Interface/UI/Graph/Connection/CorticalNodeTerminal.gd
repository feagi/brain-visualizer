extends HBoxContainer
class_name CorticalNodeTerminal
## Terminal below cortical area that is specific for a specific connection

enum TYPE {
	INPUT,
	OUTPUT,
	RECURSSIVE
}


var terminal_type: TYPE:
	get: return _terminal_type
var connected_area: CorticalArea:
	get: return _connected_area
var representing_area: CorticalArea:
	get: return _parent_node.cortical_area_ref

var _terminal_type: TYPE ## The type of terminal
var _input_point: TextureRect
var _output_point: TextureRect
var _connected_area: CorticalArea
var _parent_node: CorticalNode
var _cortical_label: Button


func _ready() -> void:
	_cortical_label = $Label
	_input_point = $input
	_output_point = $output

func setup(connecting_area: CorticalArea, parent_node: CorticalNode, type_terminal: TYPE) -> void:
	_connected_area = connecting_area
	_terminal_type = type_terminal
	_parent_node = parent_node
	_parent_node.add_child(self)
	
	_cortical_label.text = _connected_area.name
	name = _connected_area.cortical_ID
	_connected_area.name_updated.connect(_cortical_name_update)
	match type_terminal:
		TYPE.INPUT:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_cortical_label.tooltip_text = "Afferent Connection"
			_input_point.visible = true
		TYPE.OUTPUT:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_cortical_label.tooltip_text = "Efferent Connection"
			_output_point.visible = true
		TYPE.RECURSSIVE:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
			_cortical_label.tooltip_text = "Connection to Self"
		_:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
			push_error("UI: GRAPH: Unknown Terminal Type") 

## Sets the color of this single port
func set_port_color(color: Color) -> void:
	print("TODO color")
	#TODO

func get_input_location() -> Vector2:
	return _parent_node.position_offset + position + _input_point.position

func get_output_location() -> Vector2:
	return _parent_node.position_offset + position + _output_point.position

func _cortical_name_update(new_name: String, _area: CorticalArea) -> void:
	_cortical_label.text = new_name

#TODO have the button send you to the cortical Area
