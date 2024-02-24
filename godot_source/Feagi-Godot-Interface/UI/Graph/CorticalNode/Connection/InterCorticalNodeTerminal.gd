extends HBoxContainer
class_name InterCorticalNodeTerminal
## Terminal below cortical area that is specific for a specific connection

signal line_highlighting_set(line_highlighting: bool)

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
var _active_point: TerminalPortTexture

var _connected_area: BaseCorticalArea
var _parent_node: CorticalNode
var _cortical_label: Button

func _ready() -> void:
	_cortical_label = $Label
	_active_point = $input # NOTE: This will possibly be overridden on the Setup function, we just don't want this to be null!
	set_notify_local_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		_terminal_location_changed()

func setup(mapping_properties: MappingProperties, type_terminal: TYPE, when_node_moves: Signal) -> void:
	_parent_node = get_parent()
	_terminal_type = type_terminal
	
	match type_terminal:
		TYPE.INPUT:
			_connected_area = mapping_properties.source_cortical_area
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_cortical_label.tooltip_text = "Afferent Connection"
			_active_point = $input
			_active_point.visible = true
			_active_point.setup(mapping_properties)
		TYPE.OUTPUT:
			_connected_area = mapping_properties.destination_cortical_area
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_cortical_label.tooltip_text = "Efferent Connection"
			_active_point = $output
			_active_point.visible = true
			_active_point.setup(mapping_properties)
		_:
			_cortical_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
			push_error("UI: GRAPH: Unknown Terminal Type")
			_cortical_label.text = "ERROR"

	_cortical_label.text = _connected_area.name
	name = _connected_area.cortical_ID
	_connected_area.name_updated.connect(_cortical_name_update)
	when_node_moves.connect(_terminal_location_changed)
	_parent_node.node_selected.connect(_parent_node_selected)
	_parent_node.node_deselected.connect(_parent_node_deselected)

## Get reference to child [TerminalPortTexture]
func get_port_reference() -> TerminalPortTexture:
	return _active_point

## Get center point of the input terminal
func get_input_location() -> Vector2:
	return Vector2(_parent_node.position_offset) + Vector2(position) + Vector2(_active_point.position) + (_active_point.size / 2.0)

## Get center point of the output terminal
func get_output_location() -> Vector2:
	return Vector2(_parent_node.position_offset) + Vector2(position) + Vector2(_active_point.position) + (_active_point.size / 2.0)

func _terminal_location_changed()-> void:
	_active_point.node_move_terminal()

func _cortical_name_update(new_name: String, _area: BaseCorticalArea) -> void:
	_cortical_label.text = new_name

func _parent_node_selected() -> void:
	line_highlighting_set.emit(true)

func _parent_node_deselected() -> void:
	line_highlighting_set.emit(false)

#TODO have the button send you to the cortical Area
