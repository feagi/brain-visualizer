extends RefCounted
class_name LayeredGraphLayout
## Layered left-to-right layout shared by Circuit Builder and the Circuit Schematic.
## Inputs go in the left column, outputs in the right, region IO in the inner columns. Everything else
## goes in layered columns by edge direction (downstream right). Cycles share a layer via SCC + longest
## path on the component DAG, and nodes in a layer are ordered by the barycenter of their neighbours.
## Works on plain data: any hashable value can be an item key, so callers keep their own node objects.

enum COLUMN { INPUT, MIDDLE, OUTPUT, INNER_INPUT, INNER_OUTPUT }

const DEFAULT_COLUMN_GAP: float = 480.0
const DEFAULT_ROW_GAP: float = 48.0
const DEFAULT_LAYER_GAP: float = 480.0

var _column_gap: float
var _row_gap: float
var _layer_gap: float
var _size_of: Dictionary = {}
var _position_of: Dictionary = {}
var _priority_of: Dictionary = {}

var _tarjan_index: int = 0
var _tarjan_indices: Dictionary = {}
var _tarjan_lowlink: Dictionary = {}
var _tarjan_stack: Array = []
var _tarjan_on_stack: Dictionary = {}
var _tarjan_adj: Dictionary = {}
var _tarjan_sccs: Array = []


## [param items]: Dictionaries with "key", "size" (Vector2), "position" (current Vector2), "column" ([enum COLUMN])
## and optional "priority" (int, lower sorts first within the input/output column).
## [param edges]: [source_key, destination_key] pairs in link order; duplicates allowed, self edges ignored.
## Region IO items (inner columns) take no part in edges. Returns key -> Vector2.
static func compute(items: Array, edges: Array, column_gap: float = DEFAULT_COLUMN_GAP, row_gap: float = DEFAULT_ROW_GAP, layer_gap: float = DEFAULT_LAYER_GAP) -> Dictionary:
	var layout: LayeredGraphLayout = LayeredGraphLayout.new()
	layout._column_gap = column_gap
	layout._row_gap = row_gap
	layout._layer_gap = layer_gap
	return layout._compute(items, edges)


func _compute(items: Array, edges: Array) -> Dictionary:
	var nodes: Array = []
	var region_io_nodes: Array = []
	var inputs: Array = []
	var outputs: Array = []
	var middle: Array = []
	var inner_inputs: Array = []
	var inner_outputs: Array = []
	var column_of: Dictionary = {}
	for item: Dictionary in items:
		var key: Variant = item["key"]
		_size_of[key] = item["size"]
		_position_of[key] = item["position"]
		_priority_of[key] = int(item.get("priority", 0))
		var column: COLUMN = item["column"]
		column_of[key] = column
		match column:
			COLUMN.INNER_INPUT:
				region_io_nodes.append(key)
				inner_inputs.append(key)
			COLUMN.INNER_OUTPUT:
				region_io_nodes.append(key)
				inner_outputs.append(key)
			COLUMN.INPUT:
				nodes.append(key)
				inputs.append(key)
			COLUMN.OUTPUT:
				nodes.append(key)
				outputs.append(key)
			_:
				nodes.append(key)
				middle.append(key)
	if nodes.is_empty() and region_io_nodes.is_empty():
		return {}
	var adjacency: Dictionary = _build_adjacency(edges)
	var origin_nodes: Array = nodes if not nodes.is_empty() else region_io_nodes
	var min_x: float = _min_position(origin_nodes).x
	var min_y: float = _min_position(origin_nodes).y
	var left_x: float = min_x
	var inner_left_x: float = left_x + _max_width(inputs) + _column_gap
	var middle_x: float = inner_left_x + _max_width(inner_inputs) + _column_gap
	var middle_width_span: float = _middle_width_span(middle, edges)
	var inner_right_x: float = middle_x + middle_width_span + _column_gap
	var right_x: float = inner_right_x + _max_width(inner_outputs) + _column_gap
	# Place IO columns first, then position interconnects between them.
	var input_positions: Dictionary = _layout_column(_sort_by_priority_then_y(inputs), left_x, min_y)
	var output_positions: Dictionary = _layout_column(_sort_by_priority_then_y(outputs), right_x, min_y)
	var inner_input_positions: Dictionary = _layout_column(_sort_by_current_y(inner_inputs), inner_left_x, min_y)
	var inner_output_positions: Dictionary = _layout_column(_sort_by_current_y(inner_outputs), inner_right_x, min_y)
	var io_y_map: Dictionary = {}
	for positions: Dictionary in [input_positions, output_positions, inner_input_positions, inner_output_positions]:
		for key in positions.keys():
			io_y_map[key] = (positions[key] as Vector2).y
	var middle_positions: Dictionary = _layout_middle_hierarchical(middle, edges, adjacency, io_y_map, middle_x, min_y)
	var layout_positions: Dictionary = {}
	for positions: Dictionary in [output_positions, inner_output_positions, middle_positions, inner_input_positions, input_positions]:
		for key in positions.keys():
			layout_positions[key] = positions[key]
	# Enforce strict column placement for inputs/outputs; interconnect keeps its hierarchical X.
	for key in nodes:
		if column_of[key] == COLUMN.INPUT:
			_set_column_x(layout_positions, key, left_x)
		elif column_of[key] == COLUMN.OUTPUT:
			_set_column_x(layout_positions, key, right_x)
	for key in region_io_nodes:
		_set_column_x(layout_positions, key, inner_left_x if column_of[key] == COLUMN.INNER_INPUT else inner_right_x)
	return layout_positions


## Undirected adjacency for barycenter ordering, keyed in first-seen order.
func _build_adjacency(edges: Array) -> Dictionary:
	var adjacency: Dictionary = {}
	for edge in edges:
		var source: Variant = edge[0]
		var destination: Variant = edge[1]
		if source == destination:
			continue
		if not adjacency.has(source):
			adjacency[source] = []
		if not adjacency.has(destination):
			adjacency[destination] = []
		adjacency[source].append(destination)
		adjacency[destination].append(source)
	return adjacency


## Directed edges between middle-column items only.
func _directed_middle_edges(edges: Array, middle_membership: Dictionary) -> Array:
	var directed: Array = []
	for edge in edges:
		var source: Variant = edge[0]
		var destination: Variant = edge[1]
		if source == destination:
			continue
		if not middle_membership.has(source) or not middle_membership.has(destination):
			continue
		directed.append([source, destination])
	return directed


func _out_adjacency(nodes: Array, directed_edges: Array) -> Dictionary:
	var adjacency: Dictionary = {}
	for node in nodes:
		adjacency[node] = []
	for edge in directed_edges:
		adjacency[edge[0]].append(edge[1])
	return adjacency


func _tarjan_run_scc(nodes: Array, adjacency: Dictionary) -> Array:
	_tarjan_index = 0
	_tarjan_indices.clear()
	_tarjan_lowlink.clear()
	_tarjan_stack.clear()
	_tarjan_on_stack.clear()
	_tarjan_adj = adjacency
	_tarjan_sccs.clear()
	for node in nodes:
		if not _tarjan_indices.has(node):
			_tarjan_strongconnect(node)
	return _tarjan_sccs


func _tarjan_strongconnect(v: Variant) -> void:
	_tarjan_indices[v] = _tarjan_index
	_tarjan_lowlink[v] = _tarjan_index
	_tarjan_index += 1
	_tarjan_stack.append(v)
	_tarjan_on_stack[v] = true
	for w in _tarjan_adj.get(v, []):
		if not _tarjan_indices.has(w):
			_tarjan_strongconnect(w)
			_tarjan_lowlink[v] = min(_tarjan_lowlink[v], _tarjan_lowlink[w])
		elif _tarjan_on_stack.get(w, false):
			_tarjan_lowlink[v] = min(_tarjan_lowlink[v], _tarjan_indices[w])
	if _tarjan_lowlink[v] == _tarjan_indices[v]:
		var scc: Array = []
		while true:
			var w: Variant = _tarjan_stack.pop_back()
			_tarjan_on_stack[w] = false
			scc.append(w)
			if w == v:
				break
		_tarjan_sccs.append(scc)


## SCC condensation + longest path on the DAG of components (ties reciprocal cycles to one X layer).
func _condensation_longest_path_layers(nodes: Array, directed_edges: Array) -> Dictionary:
	var result: Dictionary = {}
	if nodes.is_empty():
		return result
	var sccs: Array = _tarjan_run_scc(nodes, _out_adjacency(nodes, directed_edges))
	var node_to_scc: Dictionary = {}
	for i in range(sccs.size()):
		for node in sccs[i]:
			node_to_scc[node] = i
	var num_scc: int = sccs.size()
	var cond_adj: Dictionary = {}
	var indegree: Array = []
	indegree.resize(num_scc)
	for i in range(num_scc):
		indegree[i] = 0
		cond_adj[i] = []
	var edge_seen: Dictionary = {}
	for edge in directed_edges:
		var su: int = node_to_scc[edge[0]]
		var sv: int = node_to_scc[edge[1]]
		if su == sv:
			continue
		var key: String = "%d>%d" % [su, sv]
		if edge_seen.has(key):
			continue
		edge_seen[key] = true
		cond_adj[su].append(sv)
		indegree[sv] += 1
	var queue: Array = []
	for i in range(num_scc):
		if indegree[i] == 0:
			queue.append(i)
	var topo: Array = []
	while not queue.is_empty():
		var u: int = queue.pop_front()
		topo.append(u)
		for v in cond_adj.get(u, []):
			indegree[v] -= 1
			if indegree[v] == 0:
				queue.append(v)
	for i in range(num_scc):
		if not i in topo:
			topo.append(i)
	var dist: Dictionary = {}
	for i in range(num_scc):
		dist[i] = 0
	for u in topo:
		for v in cond_adj.get(u, []):
			if dist[v] < dist[u] + 1:
				dist[v] = dist[u] + 1
	for node in nodes:
		result[node] = dist[node_to_scc[node]]
	return result


## Middle items grouped by layer index, layers in ascending order with items in input order.
func _middle_layers(middle: Array, edges: Array) -> Array:
	var membership: Dictionary = {}
	for node in middle:
		membership[node] = true
	var layer_of: Dictionary = _condensation_longest_path_layers(middle, _directed_middle_edges(edges, membership))
	var max_layer: int = -1
	var layers: Dictionary = {}
	for node in middle:
		var layer: int = layer_of[node]
		max_layer = max(max_layer, layer)
		if not layers.has(layer):
			layers[layer] = []
		layers[layer].append(node)
	var ordered: Array = []
	for layer in range(max_layer + 1):
		if layers.has(layer):
			ordered.append(layers[layer])
	return ordered


func _middle_width_span(middle: Array, edges: Array) -> float:
	if middle.is_empty():
		return 0.0
	var span: float = 0.0
	var first_layer: bool = true
	for layer_nodes: Array in _middle_layers(middle, edges):
		if not first_layer:
			span += _layer_gap
		first_layer = false
		span += _max_width(layer_nodes)
	return span


func _layout_middle_hierarchical(middle: Array, edges: Array, adjacency: Dictionary, io_y_map: Dictionary, middle_base_x: float, start_y: float) -> Dictionary:
	var positions: Dictionary = {}
	if middle.is_empty():
		return positions
	var cursor_x: float = middle_base_x
	for layer_nodes: Array in _middle_layers(middle, edges):
		var ordered: Array = _sort_by_barycenter(layer_nodes, adjacency, io_y_map)
		var column_positions: Dictionary = _layout_column(ordered, cursor_x, start_y)
		for node in ordered:
			positions[node] = column_positions[node]
		cursor_x += _max_width(ordered) + _layer_gap
	return positions


func _sort_by_barycenter(nodes: Array, adjacency: Dictionary, ref_y_map: Dictionary) -> Array:
	var sortable: Array[Dictionary] = []
	for node in nodes:
		var neighbor_ys: Array[float] = []
		for neighbor in adjacency.get(node, []):
			if not ref_y_map.is_empty() and ref_y_map.has(neighbor):
				neighbor_ys.append(ref_y_map[neighbor])
			else:
				neighbor_ys.append((_position_of[neighbor] as Vector2).y)
		var desired_y: float = (_position_of[node] as Vector2).y
		if not neighbor_ys.is_empty():
			desired_y = _average(neighbor_ys)
		sortable.append({"node": node, "y": desired_y})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
	)
	return sortable.map(func(entry: Dictionary) -> Variant: return entry["node"])


func _sort_by_priority_then_y(nodes: Array) -> Array:
	var sortable: Array[Dictionary] = []
	for node in nodes:
		sortable.append({"node": node, "priority": _priority_of[node], "y": (_position_of[node] as Vector2).y})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a: int = int(a.get("priority", 0))
		var priority_b: int = int(b.get("priority", 0))
		if priority_a == priority_b:
			return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
		return priority_a < priority_b
	)
	return sortable.map(func(entry: Dictionary) -> Variant: return entry["node"])


func _sort_by_current_y(nodes: Array) -> Array:
	var sortable: Array[Dictionary] = []
	for node in nodes:
		sortable.append({"node": node, "y": (_position_of[node] as Vector2).y})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
	)
	return sortable.map(func(entry: Dictionary) -> Variant: return entry["node"])


func _layout_column(nodes: Array, column_x: float, start_y: float) -> Dictionary:
	var positions: Dictionary = {}
	var cursor_y: float = start_y
	for node in nodes:
		positions[node] = Vector2(column_x, cursor_y)
		cursor_y += (_size_of[node] as Vector2).y + _row_gap
	return positions


func _set_column_x(layout_positions: Dictionary, key: Variant, target_x: float) -> void:
	var new_position: Vector2 = Vector2(target_x, (_position_of[key] as Vector2).y)
	if layout_positions.has(key):
		new_position.y = (layout_positions[key] as Vector2).y
	layout_positions[key] = new_position


func _min_position(nodes: Array) -> Vector2:
	var result: Vector2 = _position_of[nodes[0]]
	for node in nodes:
		result.x = min(result.x, (_position_of[node] as Vector2).x)
		result.y = min(result.y, (_position_of[node] as Vector2).y)
	return result


func _max_width(nodes: Array) -> float:
	var max_width: float = 0.0
	for node in nodes:
		max_width = max(max_width, (_size_of[node] as Vector2).x)
	return max_width


func _average(values: Array[float]) -> float:
	var total: float = 0.0
	for value in values:
		total += value
	return total / float(values.size())
