extends RefCounted
class_name SchematicModel
## Plain-data tree of the whole genome for the Circuit Schematic. No nodes live here.
## Items are regions, cortical areas and classifiers. [method layout] sizes every region bottom-up
## with [LayeredGraphLayout], so a closed region takes exactly the space its open frame needs.
## [method group_lines] merges mappings by the object visible at each end.

enum KIND { REGION, AREA, CLASSIFIER }
enum LINE_KIND { EXCITATORY, INHIBITORY, EPISODIC, MIXED }

const LEAF_SIZE: Vector2 = Vector2(220, 64)
const MIN_REGION_SIZE: Vector2 = Vector2(280, 128)
const PAD: float = 32.0
const HEADER: float = 48.0
const COLUMN_GAP: float = 120.0
const ROW_GAP: float = 28.0
const LAYER_GAP: float = 120.0

## One Dictionary per item. Keys: kind, name, object, parent, children, depth, size, local, global,
## column, priority, saved_position, color, closed_only, area_count, region_count.
var items: Array[Dictionary] = []
## Each mapping as [source item, destination item, LINE_KIND].
var mappings: Array[PackedInt32Array] = []
## Per item: its ancestor regions, root first.
var ancestors: Array[PackedInt32Array] = []
var canvas_rect: Rect2 = Rect2()


## Adds an item under [param parent] (-1 for the root) and returns its index.
## [param extra] may set column, priority, saved_position, color and closed_only.
func add_item(kind: KIND, item_name: String, parent: int, object: Object = null, extra: Dictionary = {}) -> int:
	var item: Dictionary = {
		"kind": kind, "name": item_name, "object": object, "parent": parent, "children": [], "depth": 0,
		"size": LEAF_SIZE, "local": Vector2.ZERO, "global": Vector2.ZERO,
		"column": extra.get("column", LayeredGraphLayout.COLUMN.MIDDLE), "priority": int(extra.get("priority", 0)),
		"saved_position": extra.get("saved_position", Vector2.ZERO), "color": extra.get("color", Color.GRAY),
		"closed_only": bool(extra.get("closed_only", false)), "area_count": 0, "region_count": 0,
	}
	var index: int = items.size()
	items.append(item)
	if parent >= 0:
		item["depth"] = int(items[parent]["depth"]) + 1
		items[parent]["children"].append(index)
	return index


## Mappings whose ends are the same item are not drawn and are ignored.
func add_mapping(source: int, destination: int, line_kind: LINE_KIND) -> void:
	if source == destination:
		return
	mappings.append(PackedInt32Array([source, destination, line_kind]))


func is_region(index: int) -> bool:
	return items[index]["kind"] == KIND.REGION


## Call once every item and mapping is added: fills ancestors and counts, then lays everything out.
func finish() -> void:
	ancestors.resize(items.size())
	for i in items.size():
		var chain: PackedInt32Array = []
		var parent: int = items[i]["parent"]
		while parent != -1:
			chain.append(parent)
			parent = items[parent]["parent"]
		chain.reverse()
		ancestors[i] = chain
	for i in range(items.size() - 1, -1, -1):
		var parent: int = items[i]["parent"]
		if parent == -1:
			continue
		if is_region(i):
			items[parent]["region_count"] += 1 + int(items[i]["region_count"])
			items[parent]["area_count"] += int(items[i]["area_count"])
		else:
			items[parent]["area_count"] += 1
	layout()


func layout() -> void:
	if items.is_empty():
		canvas_rect = Rect2()
		return
	var sibling_edges: Dictionary = _sibling_edges()
	_layout_region(0, sibling_edges)
	items[0]["global"] = Vector2.ZERO
	_place_global(0)
	canvas_rect = Rect2(Vector2.ZERO, items[0]["size"])


func global_rect(index: int) -> Rect2:
	return Rect2(items[index]["global"], items[index]["size"])


## Only the root open.
func default_open_mask() -> PackedByteArray:
	var mask: PackedByteArray = []
	mask.resize(items.size())
	if not items.is_empty():
		mask[0] = 1
	return mask


## Items whose ancestors are all open, parents before children.
func visible_items(open: PackedByteArray) -> Array[int]:
	var result: Array[int] = []
	if items.is_empty():
		return result
	var stack: Array[int] = [0]
	while not stack.is_empty():
		var index: int = stack.pop_back()
		result.append(index)
		if is_region(index) and open[index] == 1:
			var children: Array = items[index]["children"]
			for i in range(children.size() - 1, -1, -1):
				stack.append(children[i])
	return result


## The item itself when every region above it is open, otherwise the outermost closed region above it.
func visible_end(index: int, open: PackedByteArray) -> int:
	for ancestor in ancestors[index]:
		if open[ancestor] == 0:
			return ancestor
	return index


## Merges mappings by their visible ends.
## Returns {"lines": [[from, to, count, LINE_KIND]], "inside": {closed region: mappings hidden inside it}}.
func group_lines(open: PackedByteArray) -> Dictionary:
	var groups: Dictionary = {}
	var inside: Dictionary = {}
	for mapping in mappings:
		var from: int = visible_end(mapping[0], open)
		var to: int = visible_end(mapping[1], open)
		if from == to:
			inside[from] = int(inside.get(from, 0)) + 1
			continue
		var key: int = from * items.size() + to
		if not groups.has(key):
			groups[key] = [from, to, 0, mapping[2]]
		var group: Array = groups[key]
		group[2] += 1
		if group[3] != mapping[2]:
			group[3] = LINE_KIND.MIXED
	return {"lines": groups.values(), "inside": inside}


## For each region, edges between its direct children: every mapping becomes an edge in the region
## where its two ends part ways, between the two children holding them.
func _sibling_edges() -> Dictionary:
	var edges: Dictionary = {}
	for mapping in mappings:
		var source_path: PackedInt32Array = ancestors[mapping[0]].duplicate()
		source_path.append(mapping[0])
		var destination_path: PackedInt32Array = ancestors[mapping[1]].duplicate()
		destination_path.append(mapping[1])
		var depth: int = 0
		while depth + 1 < source_path.size() and depth + 1 < destination_path.size() and source_path[depth + 1] == destination_path[depth + 1]:
			depth += 1
		if depth + 1 >= source_path.size() or depth + 1 >= destination_path.size():
			continue # one end contains the other
		var region: int = source_path[depth]
		if not edges.has(region):
			edges[region] = []
		edges[region].append([source_path[depth + 1], destination_path[depth + 1]])
	return edges


func _layout_region(index: int, sibling_edges: Dictionary) -> void:
	var children: Array = items[index]["children"]
	if children.is_empty():
		items[index]["size"] = MIN_REGION_SIZE
		return
	var layout_items: Array = []
	for child in children:
		if is_region(child):
			_layout_region(child, sibling_edges)
		layout_items.append({"key": child, "size": items[child]["size"], "position": items[child]["saved_position"],
			"column": items[child]["column"], "priority": items[child]["priority"]})
	var positions: Dictionary = LayeredGraphLayout.compute(layout_items, sibling_edges.get(index, []), COLUMN_GAP, ROW_GAP, LAYER_GAP)
	var bounds: Rect2 = Rect2(positions[children[0]], items[children[0]]["size"])
	for child in children:
		bounds = bounds.merge(Rect2(positions[child], items[child]["size"]))
	var offset: Vector2 = Vector2(PAD, HEADER + PAD) - bounds.position
	for child in children:
		items[child]["local"] = (positions[child] as Vector2) + offset
	items[index]["size"] = Vector2(maxf(bounds.size.x + PAD * 2.0, MIN_REGION_SIZE.x), maxf(bounds.size.y + HEADER + PAD * 2.0, MIN_REGION_SIZE.y))


func _place_global(index: int) -> void:
	for child in items[index]["children"]:
		items[child]["global"] = items[index]["global"] + items[child]["local"]
		if is_region(child):
			_place_global(child)
