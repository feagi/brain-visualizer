extends SceneTree
## SchematicReachability: the items and mappings related to one item, for the hover dim.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/CircuitSchematic/test_schematic_reachability.gd


func _initialize() -> void:
	var failures: int = 0
	failures += _test_chain()
	failures += _test_cycle()
	failures += _test_branch()
	failures += _test_against_arrow()
	failures += _test_bypass()
	failures += _test_isolated()
	if failures == 0:
		print("Schematic reachability tests: PASS")
		quit(0)
	else:
		push_error("Schematic reachability tests: FAIL (%d)" % failures)
		quit(1)


## Flat model: every named area under one root. [param edges] are [from, to] name pairs; mapping index = edge order.
func _model(names: Array, edges: Array) -> Array:
	var model: SchematicModel = SchematicModel.new()
	var root: int = model.add_item(SchematicModel.KIND.REGION, "root", -1)
	var ids: Dictionary = {}
	for n in names:
		ids[n] = model.add_item(SchematicModel.KIND.AREA, n, root)
	for edge in edges:
		model.add_mapping(ids[edge[0]], ids[edge[1]], SchematicModel.LINE_KIND.EXCITATORY)
	model.finish()
	return [SchematicReachability.new(model), ids]


func _check(label: String, related: Dictionary, ids: Dictionary, want_items: Array, want_mappings: Array) -> int:
	var items: Array = []
	for n in want_items:
		items.append(ids[n])
	items.sort()
	var got_items: Array = related.items.keys()
	got_items.sort()
	var got_mappings: Array = related.mappings.keys()
	got_mappings.sort()
	if got_items != items or got_mappings != want_mappings:
		push_error("%s: items %s (want %s), mappings %s (want %s)" % [label, got_items, items, got_mappings, want_mappings])
		return 1
	return 0


func _test_chain() -> int:
	var m: Array = _model(["a", "b", "c", "d"], [["a", "b"], ["b", "c"], ["c", "d"]])
	return _check("chain", m[0].related_to(m[1].b), m[1], ["a", "b", "c", "d"], [0, 1, 2])


func _test_cycle() -> int:
	var m: Array = _model(["a", "b", "c"], [["a", "b"], ["b", "c"], ["c", "a"]])
	return _check("cycle", m[0].related_to(m[1].a), m[1], ["a", "b", "c"], [0, 1, 2])


func _test_branch() -> int:
	# h feeds x and y; w feeds h; z is a sibling branch off w that h does not reach.
	var m: Array = _model(["w", "h", "x", "y", "z"], [["w", "h"], ["h", "x"], ["h", "y"], ["w", "z"]])
	return _check("branch", m[0].related_to(m[1].h), m[1], ["w", "h", "x", "y"], [0, 1, 2])


func _test_against_arrow() -> int:
	# p -> h and p -> q: q is only reachable from h against the arrow of p -> q, so it stays dim.
	var m: Array = _model(["p", "h", "q"], [["p", "h"], ["p", "q"]])
	return _check("against-arrow", m[0].related_to(m[1].h), m[1], ["p", "h"], [0])


func _test_bypass() -> int:
	# u -> h, h -> v and u -> v: all three items lit, but the bypass u -> v stays dim.
	var m: Array = _model(["u", "h", "v"], [["u", "h"], ["h", "v"], ["u", "v"]])
	return _check("bypass", m[0].related_to(m[1].h), m[1], ["u", "h", "v"], [0, 1])


func _test_isolated() -> int:
	var m: Array = _model(["a", "b", "c"], [["a", "b"]])
	return _check("isolated", m[0].related_to(m[1].c), m[1], ["c"], [])
