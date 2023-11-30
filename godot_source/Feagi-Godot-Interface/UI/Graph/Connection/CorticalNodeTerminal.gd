extends HBoxContainer
class_name CorticalNodeTerminal
## Terminal below cortical area that is specific for a specific connection

enum TYPE {
	INPUT,
	OUTPUT
}


var terminal_type: TYPE:
	get: return _terminal_type
var slot_index: int:
	get: return _slot_index
var port_index: int:
	get: return _port_index
var connected_area: CorticalArea:
	get: return _connected_area
var representing_area: CorticalArea:
	get: return _parent_node.cortical_area_ref

var _terminal_type: TYPE ## The type of terminal
var _slot_index: int
var _port_index: int
var _connected_area: CorticalArea
var _parent_node: CorticalNode
var _cortical_label: Button


func _ready() -> void:
	_cortical_label = $Label

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
		TYPE.OUTPUT:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_cortical_label.tooltip_text = "Efferent Connection"
		_:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
			push_error("UI: GRAPH: Unknown Terminal Type") 

## Update all cached indexes
func update_indexes() -> void:
	_slot_index = _get_slot_index()
	_port_index = _get_port_index()

## Sets the color of this single port
func set_port_color(color: Color) -> void:
	match _terminal_type:
		TYPE.INPUT:
			_parent_node.set_slot_color_left(_slot_index, color)
		TYPE.OUTPUT:
			_parent_node.set_slot_color_right(_slot_index, color)
		_:
			push_error("UI: GRAPH: Unable to set color for unknown terminal type!")

func get_port_position() -> Vector2:
	match _terminal_type:
		TYPE.INPUT:
			return _parent_node.get_input_port_position(_port_index) + _parent_node.position_offset
		TYPE.OUTPUT:
			return _parent_node.get_output_port_position(_port_index) + _parent_node.position_offset
	push_error("UI: GRAPH: Unable to get port position on expceptional terminal!")
	return Vector2(0,0)

## Get the slot index of this terminal
func _get_slot_index() -> int:
	return get_index()

## Get the port index of this terminal
func _get_port_index() -> int: # This is cursed
	var slot: int
	match _terminal_type:
		TYPE.INPUT:
			for port in _parent_node.get_input_port_count():
				slot = _parent_node.get_input_port_slot(port)
				if _slot_index == slot:
					return port
		TYPE.OUTPUT:
			for port in _parent_node.get_output_port_count():
				slot = _parent_node.get_output_port_slot(port)
				if _slot_index == slot:
					return port
	push_error("UI: GRAPH: Unable to resolve port index for %s!" % _parent_node._cortical_area_ref.cortical_ID)
	return 0
		

func _cortical_name_update(new_name: String, _area: CorticalArea) -> void:
	_cortical_label.text = new_name

#TODO have the button send you to the cortical Area
