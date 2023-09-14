extends Connection2DBase
class_name Connection2DConfirmed


const DEFAULT_COLOR: Color = Color(1,1,1,1)
const DEFAULT_THICKNESS: float = 5.0

var _destination_cortical_area: CorticalArea
var _connection_button: Connection2DButton

func _init(line_source_node: CorticalNode, line_destination_node: CorticalNode, number_of_mappings: int, parent_object: CanvasItem) -> void:
    parent_object.add_child(self)
    super()
    set_line_source_node(line_source_node)
    set_line_destination_node(line_destination_node)
    _destination_cortical_area = line_destination_node.cortical_area_ref
    default_color = DEFAULT_COLOR
    width = DEFAULT_THICKNESS

    _connection_button = Connection2DButton.new(number_of_mappings)
    add_child(_connection_button)
    _connection_button.update_position(mid_point)
    mid_point_changed_position.connect(_connection_button.update_position)
    name = line_source_node.cortical_area_ID + "_" + line_destination_node.cortical_area_ID

    if line_source_node.connection_output.connection_state == ConnectionButtonPoint.CONNECTION_STATE.EMPTY:
        line_source_node.connection_output.connection_state = ConnectionButtonPoint.CONNECTION_STATE.FILLED
    if line_destination_node.connection_input.connection_state == ConnectionButtonPoint.CONNECTION_STATE.EMPTY:
        line_destination_node.connection_input.connection_state = ConnectionButtonPoint.CONNECTION_STATE.FILLED

func update_mapping(num_mappings: int) -> void:
    _connection_button.update_mapping_counter(num_mappings)

