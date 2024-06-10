extends CBNodeConnectableBase
class_name CBNodeRegionIO
## Represents an input / output of the region from the INSIDE of said region

const CONNECTED_NODE_OFFSET: Vector2 = Vector2(500, -50)

var _is_input: bool

## Called by CB right after instantiation
func setup(parent_region: BrainRegion, is_input: bool) -> void:
	var input_path: NodePath = NodePath("Inputs")
	var output_path: NodePath = NodePath("Outputs")
	var recursive_path: NodePath = NodePath("") # this cannot be recursive
	setup_base(recursive_path, input_path, output_path)
	_is_input = is_input
	CACHE_updated_region_name(parent_region.friendly_name)
	parent_region.friendly_name_updated.connect(CACHE_updated_region_name)

## Called by [CircuitBuilder] when adding a connection to the Node object, EXTENDED in this class because any deletion of the single terminal implies that this whole node should go
func CB_add_connection_terminal(connection_type: CBNodeTerminal.TYPE, text: StringName, port_prefab: PackedScene) -> CBNodeTerminal:
	var terminal: CBNodeTerminal = super(connection_type, text, port_prefab)
	terminal.terminal_about_to_be_deleted.connect(queue_free)
	return terminal

## Updates the title text of the node
func CACHE_updated_region_name(name_text: StringName) -> void:
	var text: StringName
	if _is_input:
		text = "Input of "
	else:
		text = "Output of "
	title = text + name_text

