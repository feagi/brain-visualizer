extends SceneTree
## LayeredGraphLayout must place every node exactly where Circuit Builder's old auto-layout did.
## Compares it against the frozen pre-extraction copy on seeded random graphs (cycles, duplicate and
## self links, null link ends, IO priorities, region IO, tied Y positions).
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/GraphLayout/test_layered_graph_layout.gd

const LegacyLayout = preload("res://BrainVisualizer/UI/GraphLayout/legacy_cb_layout_reference.gd")
const GRAPH_COUNT: int = 400


func _initialize() -> void:
	var failures: int = 0
	failures += _test_empty_graph()
	for seed in GRAPH_COUNT:
		failures += _test_matches_legacy(seed)
	failures += _test_cycle_shares_layer()
	if failures == 0:
		print("Layered graph layout tests: PASS (%d random graphs)" % GRAPH_COUNT)
		quit(0)
	else:
		push_error("Layered graph layout tests: FAIL (%d)" % failures)
		quit(1)


func _test_empty_graph() -> int:
	if not LayeredGraphLayout.compute([], []).is_empty():
		push_error("An empty graph must lay out to nothing")
		return 1
	return 0


func _test_matches_legacy(seed: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var graph: Dictionary = _random_graph(rng)
	var legacy: RefCounted = LegacyLayout.new()
	legacy.connectable = graph.connectable
	legacy.region_io = graph.region_io
	legacy.links = graph.links
	var expected: Dictionary = legacy._compute_relayout_positions()
	var actual: Dictionary = LayeredGraphLayout.compute(_items_for(graph), _edges_for(graph))
	var failed: int = 0
	if expected.keys() != actual.keys():
		push_error("Seed %d: key order differs (%d legacy, %d new)" % [seed, expected.size(), actual.size()])
		failed = 1
	else:
		for key in expected.keys():
			if expected[key] != actual[key]:
				push_error("Seed %d: %s legacy %s, new %s" % [seed, key.name, expected[key], actual[key]])
				failed = 1
				break
	for node in graph.connectable + graph.region_io:
		node.free()
	return failed


## Two areas feeding each other land in the same layer, downstream of their source.
func _test_cycle_shares_layer() -> int:
	var items: Array = [
		{"key": "a", "size": Vector2(100, 50), "position": Vector2.ZERO, "column": LayeredGraphLayout.COLUMN.MIDDLE},
		{"key": "b", "size": Vector2(100, 50), "position": Vector2.ZERO, "column": LayeredGraphLayout.COLUMN.MIDDLE},
		{"key": "c", "size": Vector2(100, 50), "position": Vector2.ZERO, "column": LayeredGraphLayout.COLUMN.MIDDLE},
	]
	var positions: Dictionary = LayeredGraphLayout.compute(items, [["a", "b"], ["b", "c"], ["c", "b"]], 10.0, 5.0, 20.0)
	if positions["b"].x == positions["c"].x and positions["b"].x > positions["a"].x:
		return 0
	push_error("Cycle b<->c must share a layer right of a: %s" % positions)
	return 1


func _random_graph(rng: RandomNumberGenerator) -> Dictionary:
	var cortical: Array = []
	for i in rng.randi_range(0, 14):
		var node: GraphElement = _stub("area_%d" % i, rng)
		node.set_meta("kind", "cortical")
		node.set_meta("side", ["left", "right", "middle", "middle"][rng.randi_range(0, 3)])
		node.set_meta("priority_in", -100 if rng.randf() < 0.15 else 0)
		node.set_meta("priority_out", [-100, -95, -94, -90][rng.randi_range(0, 3)] if rng.randf() < 0.2 else 0)
		cortical.append(node)
	var others: Array = []
	for i in rng.randi_range(0, 4):
		var node: GraphElement = _stub("region_%d" % i, rng)
		node.set_meta("kind", "region")
		others.append(node)
	for i in rng.randi_range(0, 2):
		var node: GraphElement = _stub("classifier_%d" % i, rng)
		node.set_meta("kind", "classifier")
		others.append(node)
	var connectable: Array = cortical + others
	var region_io: Array = []
	# The old layout errors on a region with only IO nodes, so IO appears only alongside members.
	if not connectable.is_empty():
		for i in rng.randi_range(0, 5):
			var node: GraphElement = _stub("io_%d" % i, rng)
			node.set_meta("kind", "region_io")
			node.set_meta("is_input_io", rng.randf() < 0.5)
			region_io.append(node)
	var links: Array = []
	if not connectable.is_empty():
		for i in rng.randi_range(0, 45):
			var source: GraphElement = connectable[rng.randi_range(0, connectable.size() - 1)]
			var destination: GraphElement = connectable[rng.randi_range(0, connectable.size() - 1)]
			if rng.randf() < 0.05:
				source = null
			links.append([source, destination])
		if links.size() > 2:
			links.append(links[0]) # duplicate link
	return {"connectable": connectable, "region_io": region_io, "links": links}


func _stub(stub_name: String, rng: RandomNumberGenerator) -> GraphElement:
	var node: GraphElement = GraphElement.new()
	node.name = stub_name
	node.size = Vector2(rng.randi_range(120, 420), rng.randi_range(60, 300)) + (Vector2(0.5, 0.25) if rng.randf() < 0.3 else Vector2.ZERO)
	# A coarse Y grid makes ties common, which exercises sort ordering.
	node.position_offset = Vector2(rng.randi_range(-2000, 2000), rng.randi_range(-8, 8) * 100)
	return node


## The same graph as LayeredGraphLayout input, built the way Circuit Builder's adapter builds it.
func _items_for(graph: Dictionary) -> Array:
	var items: Array = []
	for node: GraphElement in graph.connectable:
		var column: LayeredGraphLayout.COLUMN = LayeredGraphLayout.COLUMN.MIDDLE
		var priority: int = 0
		if node.get_meta("kind") == "cortical":
			match String(node.get_meta("side")):
				"left":
					column = LayeredGraphLayout.COLUMN.INPUT
					priority = node.get_meta("priority_in")
				"right":
					column = LayeredGraphLayout.COLUMN.OUTPUT
					priority = node.get_meta("priority_out")
		items.append({"key": node, "size": node.size, "position": node.position_offset, "column": column, "priority": priority})
	for node: GraphElement in graph.region_io:
		var column: LayeredGraphLayout.COLUMN = LayeredGraphLayout.COLUMN.INNER_INPUT if node.get_meta("is_input_io") else LayeredGraphLayout.COLUMN.INNER_OUTPUT
		items.append({"key": node, "size": node.size, "position": node.position_offset, "column": column})
	return items


func _edges_for(graph: Dictionary) -> Array:
	var edges: Array = []
	for link in graph.links:
		if link[0] != null and link[1] != null:
			edges.append(link)
	return edges
