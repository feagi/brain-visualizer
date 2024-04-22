extends RefCounted
class_name ScalingCustomMinimumSize

var _nodes_to_scale: Array[Control] = []
var _default_sizes: Array[Vector2] = []

func _init(all_nodes_to_scale:  Array[Control]):
	_nodes_to_scale = all_nodes_to_scale
	for node in _nodes_to_scale:
		_default_sizes.append(node.custom_minimum_size)

func theme_updated(new_theme: Theme) -> void:
	if !new_theme.has_constant("size_x", "generic_scale"):
		push_error("THEME: currentl loaded theme is missing 'size_x' for 'generic_scale'!")
		return
	var scaling_factor: float = float(new_theme.get_constant("size_x", "generic_scale")) / 4.0
	for i in range(0, len(_nodes_to_scale)):
		var node: Node = _nodes_to_scale[i]
		
		node.custom_minimum_size = Vector2i(int(float(_default_sizes[i].x) * scaling_factor), int(float(_default_sizes[i].y) * scaling_factor))
