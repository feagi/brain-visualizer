extends SceneTree
## SchematicModel: nested layout, visible ends and merged lines, on hand-built and seeded random trees.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/CircuitSchematic/test_schematic_model.gd

const RANDOM_TREES: int = 60


func _initialize() -> void:
	var failures: int = 0
	failures += _test_empty_model()
	failures += _test_counts_and_visible_ends()
	failures += _test_lines_merge_at_closed_regions()
	failures += _test_edges_order_siblings()
	for seed in RANDOM_TREES:
		failures += _test_random_tree(seed)
	if failures == 0:
		print("Schematic model tests: PASS")
		quit(0)
	else:
		push_error("Schematic model tests: FAIL (%d)" % failures)
		quit(1)


## root ─ vision(a, b) ─ motor(c, gait(d))
func _sample() -> Dictionary:
	var model: SchematicModel = SchematicModel.new()
	var ids: Dictionary = {}
	ids.root = model.add_item(SchematicModel.KIND.REGION, "root", -1)
	ids.vision = model.add_item(SchematicModel.KIND.REGION, "vision", ids.root)
	ids.a = model.add_item(SchematicModel.KIND.AREA, "a", ids.vision, null, {"column": LayeredGraphLayout.COLUMN.INPUT})
	ids.b = model.add_item(SchematicModel.KIND.AREA, "b", ids.vision)
	ids.motor = model.add_item(SchematicModel.KIND.REGION, "motor", ids.root)
	ids.c = model.add_item(SchematicModel.KIND.AREA, "c", ids.motor)
	ids.gait = model.add_item(SchematicModel.KIND.REGION, "gait", ids.motor)
	ids.d = model.add_item(SchematicModel.KIND.AREA, "d", ids.gait, null, {"column": LayeredGraphLayout.COLUMN.OUTPUT})
	model.add_mapping(ids.a, ids.b, SchematicModel.LINE_KIND.EXCITATORY)
	model.add_mapping(ids.b, ids.c, SchematicModel.LINE_KIND.EXCITATORY)
	model.add_mapping(ids.b, ids.d, SchematicModel.LINE_KIND.INHIBITORY)
	model.add_mapping(ids.c, ids.d, SchematicModel.LINE_KIND.EXCITATORY)
	model.add_mapping(ids.d, ids.d, SchematicModel.LINE_KIND.EXCITATORY) # recursive: ignored
	model.finish()
	return {"model": model, "ids": ids}


func _test_empty_model() -> int:
	var model: SchematicModel = SchematicModel.new()
	model.finish()
	if model.canvas_rect.size == Vector2.ZERO and model.visible_items(model.default_open_mask()).is_empty():
		return 0
	push_error("An empty model must lay out to nothing")
	return 1


func _test_counts_and_visible_ends() -> int:
	var sample: Dictionary = _sample()
	var model: SchematicModel = sample.model
	var ids: Dictionary = sample.ids
	var failed: int = 0
	if model.mappings.size() != 4:
		push_error("Recursive mapping must be dropped, got %d mappings" % model.mappings.size())
		failed = 1
	if model.items[ids.root]["area_count"] != 4 or model.items[ids.root]["region_count"] != 3 or model.items[ids.motor]["region_count"] != 1:
		push_error("Recursive counts wrong: root %d areas %d regions" % [model.items[ids.root]["area_count"], model.items[ids.root]["region_count"]])
		failed = 1
	var open: PackedByteArray = model.default_open_mask()
	if model.visible_end(ids.d, open) != ids.motor or model.visible_end(ids.a, open) != ids.vision:
		push_error("With only root open, areas must end at their top-level region")
		failed = 1
	open[ids.motor] = 1
	if model.visible_end(ids.d, open) != ids.gait or model.visible_end(ids.c, open) != ids.c:
		push_error("Opening motor must expose c and stop d at gait")
		failed = 1
	if model.visible_items(model.default_open_mask()) != [ids.root, ids.vision, ids.motor]:
		push_error("Root-only view must show root and its two regions: %s" % [model.visible_items(model.default_open_mask())])
		failed = 1
	return failed


func _test_lines_merge_at_closed_regions() -> int:
	var sample: Dictionary = _sample()
	var model: SchematicModel = sample.model
	var ids: Dictionary = sample.ids
	var grouped: Dictionary = model.group_lines(model.default_open_mask())
	var failed: int = 0
	if grouped.lines.size() != 1:
		push_error("Root-only view must merge vision->motor into one line, got %s" % [grouped.lines])
		return 1
	var line: Array = grouped.lines[0]
	if line[0] != ids.vision or line[1] != ids.motor or line[2] != 2 or line[3] != SchematicModel.LINE_KIND.MIXED:
		push_error("Merged line must be vision->motor x2 mixed, got %s" % [line])
		failed = 1
	if grouped.inside.get(ids.vision, 0) != 1 or grouped.inside.get(ids.motor, 0) != 1:
		push_error("a->b hides in vision and c->d in motor: %s" % [grouped.inside])
		failed = 1
	return failed


## b feeds c inside motor's parent, so in root vision sits left of motor; in motor, c sits left of gait.
func _test_edges_order_siblings() -> int:
	var sample: Dictionary = _sample()
	var model: SchematicModel = sample.model
	var ids: Dictionary = sample.ids
	var failed: int = 0
	if not (model.items[ids.vision]["local"].x < model.items[ids.motor]["local"].x):
		push_error("vision must be left of motor")
		failed = 1
	if not (model.items[ids.c]["local"].x < model.items[ids.gait]["local"].x):
		push_error("c must be left of gait")
		failed = 1
	return failed


func _test_random_tree(seed: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var model: SchematicModel = SchematicModel.new()
	var regions: Array[int] = [model.add_item(SchematicModel.KIND.REGION, "root", -1)]
	for i in rng.randi_range(0, 25):
		var parent: int = regions[rng.randi_range(0, regions.size() - 1)]
		if model.items[parent]["depth"] < 5:
			regions.append(model.add_item(SchematicModel.KIND.REGION, "r%d" % i, parent, null, {"saved_position": Vector2(rng.randi_range(-900, 900), rng.randi_range(-900, 900))}))
	var leaves: Array[int] = []
	for i in rng.randi_range(1, 120):
		var parent: int = regions[rng.randi_range(0, regions.size() - 1)]
		var column: int = [LayeredGraphLayout.COLUMN.INPUT, LayeredGraphLayout.COLUMN.MIDDLE, LayeredGraphLayout.COLUMN.MIDDLE, LayeredGraphLayout.COLUMN.OUTPUT][rng.randi_range(0, 3)]
		leaves.append(model.add_item(SchematicModel.KIND.AREA, "a%d" % i, parent, null, {"column": column, "saved_position": Vector2(rng.randi_range(-900, 900), rng.randi_range(-900, 900))}))
	for i in rng.randi_range(0, 300):
		model.add_mapping(leaves[rng.randi_range(0, leaves.size() - 1)], leaves[rng.randi_range(0, leaves.size() - 1)], rng.randi_range(0, 2))
	model.finish()
	var failed: int = 0
	for region in regions:
		var region_rect: Rect2 = model.global_rect(region)
		var children: Array = model.items[region]["children"]
		for i in children.size():
			var child_rect: Rect2 = model.global_rect(children[i])
			if not region_rect.encloses(child_rect):
				push_error("Seed %d: child %s escapes region %s" % [seed, model.items[children[i]]["name"], model.items[region]["name"]])
				return 1
			for j in range(i + 1, children.size()):
				if child_rect.intersects(model.global_rect(children[j])):
					push_error("Seed %d: siblings %s and %s overlap" % [seed, model.items[children[i]]["name"], model.items[children[j]]["name"]])
					return 1
	# Conservation under random open states: drawn line counts plus hidden counts equal all mappings.
	for trial in 5:
		var open: PackedByteArray = model.default_open_mask()
		for region in regions:
			if rng.randf() < 0.5:
				open[region] = 1
		var grouped: Dictionary = model.group_lines(open)
		var total: int = 0
		for line in grouped.lines:
			total += int(line[2])
			if not (line[0] in model.visible_items(open)) or not (line[1] in model.visible_items(open)):
				push_error("Seed %d: a line ends at an item that is not visible" % seed)
				return 1
		for count in grouped.inside.values():
			total += int(count)
		if total != model.mappings.size():
			push_error("Seed %d: %d drawn + hidden, %d mappings" % [seed, total, model.mappings.size()])
			failed = 1
	return failed
