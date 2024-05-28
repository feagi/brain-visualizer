extends CBLine
class_name CBLineInterTerminal
## Connects 2 terminals together in CB

const LINE_COLOR_PSPP: Color = Color.DARK_GREEN
const LINE_COLOR_PSPN: Color = Color.DARK_RED
const LINE_COLOR_TRANSPARENT: Color = Color(0,0,0,0)

var _button: Button
var _source_port: CBNodePort
var _destination_port: CBNodePort
var _link: ConnectionChainLink


## Sets up the default line behavior, by having it connect to the ports of the 2 given terminals
func setup(source_port: CBNodePort, destination_port: CBNodePort, link: ConnectionChainLink) -> void:
	line_setup()
	_button = $Button
	_source_port = source_port
	_destination_port = destination_port
	_link = link
	_update_line_endpoint_positions()
	_source_port.node_moved.connect(_update_line_endpoint_positions)
	_destination_port.node_moved.connect(_update_line_endpoint_positions)
	name = "Line_%s->%s" % [source_port.root_node.name,destination_port.root_node.name]
	
	if link.parent_chain.is_registered_to_established_mapping_set():
		# Update line to reflect properties of cortical mapping
		_on_full_mapping_change(link.parent_chain.mapping_set)
		link.parent_chain.mapping_set.mappings_changed.connect(_on_full_mapping_change)
		_button.pressed.connect(_user_pressed_button)
		return
	if link.parent_chain.is_registered_to_partial_mapping_set():
		#TODO
		return
	


func _update_line_endpoint_positions() -> void:
	var CB_source_pos: Vector2 = _source_port.get_center_port_CB_position()
	var CB_destination_pos: Vector2 = _destination_port.get_center_port_CB_position()
	position_offset = (CB_source_pos + CB_destination_pos) / 2.0
	
	
	set_line_endpoints(CB_source_pos, CB_destination_pos)

func _on_link_about_to_be_deleted() -> void:
	_source_port.request_deletion()
	_destination_port.request_deletion()

func _on_full_mapping_change(mapping_ref: InterCorticalMappingSet) -> void:
	_button.text = "  " + str(mapping_ref.number_mappings) + "  "
	if mapping_ref.is_any_PSP_multiplier_negative():
		set_line_base_color(Color(LINE_COLOR_PSPN.r, LINE_COLOR_PSPN.g, LINE_COLOR_PSPN.b, LINE_COLOR_PSPN.a))
	else:
		set_line_base_color(Color(LINE_COLOR_PSPP.r, LINE_COLOR_PSPP.g, LINE_COLOR_PSPP.b, LINE_COLOR_PSPP.a))
	set_line_dashing(mapping_ref.is_any_mapping_plastic())

func _user_pressed_button() -> void:
	BV.UI.window_manager.spawn_edit_mappings((_link.source as BaseCorticalArea), (_link.destination as BaseCorticalArea))
