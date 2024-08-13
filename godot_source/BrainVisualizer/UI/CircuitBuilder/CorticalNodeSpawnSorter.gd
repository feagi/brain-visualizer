extends Object
class_name CorticalNodeSpawnSorter
## Creturns positions of each cortical areas

var _gap_between_nodes: Vector2i
var _size_of_node: Vector2i
var _ordered_cortical_area_counter_by_type: Array[int]

func _init(gap_between_nodes: Vector2i, node_size: Vector2i)  -> void:
	_gap_between_nodes = gap_between_nodes
	_size_of_node = node_size
	for i in AbstractCorticalArea.CORTICAL_AREA_TYPE.keys():
		_ordered_cortical_area_counter_by_type.append(0) # This is Stupid. Too bad!
	
func add_cortical_area_to_memory_and_return_position(cortical_area_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> Vector2i:
	var index: int = cortical_area_type # Technically this step isnt needed, but it is here to demonstrate how the enum is being used as an int index
	var x_offset: int = index * (_gap_between_nodes.x + _size_of_node.x)
	var y_offset: int =  _ordered_cortical_area_counter_by_type[index] * (_gap_between_nodes.y + _size_of_node.y)
	_ordered_cortical_area_counter_by_type[index] = _ordered_cortical_area_counter_by_type[index] + 1
	return Vector2(x_offset, y_offset)
