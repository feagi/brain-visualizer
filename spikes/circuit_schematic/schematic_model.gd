extends RefCounted
## Plain-data region tree, nested shelf layout, open/close decision and line grouping.
## No nodes are created here; this is the "data first" half of the design.

const AREA_SIZE: Vector2 = Vector2(160, 56)
const PAD: float = 24.0
const GAP: float = 24.0
const HEADER: float = 36.0
const MIN_REGION_WIDTH: float = 200.0
const KIND_INDEX: Dictionary = {"excitatory": 0, "inhibitory": 1, "episodic": 2}

## One dictionary per region or area: id, name, kind, type, parent, children, depth, size, local, global.
var items: Array[Dictionary] = []
## Each mapping as [source item index, destination item index, kind index].
var mappings: Array[PackedInt32Array] = []
## Per item: indexes of its ancestor regions, root first.
var ancestors: Array[PackedInt32Array] = []
var region_indexes: PackedInt32Array = []
var area_indexes: PackedInt32Array = []
var canvas_rect: Rect2


func build(data: Dictionary) -> void:
	var index_of: Dictionary = {}
	for region in data.regions:
		index_of[region.id] = items.size()
		region_indexes.append(items.size())
		items.append(_item(region.id, region.name, "region", "", int(region.depth)))
	for region in data.regions:
		if region.parent != "":
			_attach(index_of[region.id], index_of[region.parent])
	for area in data.areas:
		var parent: int = index_of[area.region]
		index_of[area.id] = items.size()
		area_indexes.append(items.size())
		items.append(_item(area.id, area.name, "area", area.type, int(items[parent]["depth"]) + 1))
		_attach(items.size() - 1, parent)
	for mapping in data.mappings:
		mappings.append(PackedInt32Array([index_of[mapping.src], index_of[mapping.dst], KIND_INDEX[mapping.kind]]))
	ancestors.resize(items.size())
	for i in items.size():
		var chain: PackedInt32Array = []
		var p: int = items[i]["parent"]
		while p != -1:
			chain.append(p)
			p = items[p]["parent"]
		chain.reverse()
		ancestors[i] = chain


## Sizes every region bottom-up, then turns region-relative positions into canvas positions.
func layout() -> void:
	_layout_region(0)
	items[0]["global"] = Vector2.ZERO
	_place_global(0)
	canvas_rect = Rect2(Vector2.ZERO, items[0]["size"])


func global_rect(index: int) -> Rect2:
	return Rect2(items[index]["global"], items[index]["size"])


func mask_where(predicate: Callable) -> PackedByteArray:
	var mask: PackedByteArray = []
	mask.resize(items.size())
	for i in region_indexes:
		mask[i] = 1 if (i == 0 or predicate.call(items[i])) else 0
	return mask


## The open/close rule from the design: open above open_px on screen and near the view, close below close_px.
func decide_open(previous: PackedByteArray, view_rect: Rect2, zoom: float, open_px: float, close_px: float) -> PackedByteArray:
	var mask: PackedByteArray = []
	mask.resize(items.size())
	var near: Rect2 = view_rect.grow(maxf(view_rect.size.x, view_rect.size.y) * 0.5)
	var far: Rect2 = view_rect.grow(maxf(view_rect.size.x, view_rect.size.y))
	_decide(0, previous, mask, near, far, zoom, open_px, close_px)
	return mask


## Merges mappings by their visible ends. Returns {"edges": [[from, to, count, kind_mask]], "badges": {region: count}}.
func group_edges(open: PackedByteArray) -> Dictionary:
	var groups: Dictionary = {}
	var badges: Dictionary = {}
	for mapping in mappings:
		var from: int = visible_end(mapping[0], open)
		var to: int = visible_end(mapping[1], open)
		if from == to:
			badges[from] = int(badges.get(from, 0)) + 1
			continue
		var key: int = from * items.size() + to
		var group: Array = groups.get(key, [])
		if group.is_empty():
			group = [from, to, 0, 0]
			groups[key] = group
		group[2] += 1
		group[3] |= 1 << mapping[2]
	return {"edges": groups.values(), "badges": badges}


## The area itself when every region above it is open, otherwise the outermost closed region above it.
func visible_end(index: int, open: PackedByteArray) -> int:
	for ancestor in ancestors[index]:
		if open[ancestor] == 0:
			return ancestor
	return index


func _item(id: String, name: String, kind: String, type: String, depth: int) -> Dictionary:
	return {"id": id, "name": name, "kind": kind, "type": type, "parent": -1, "children": [], "depth": depth,
		"size": AREA_SIZE, "local": Vector2.ZERO, "global": Vector2.ZERO}


func _attach(child: int, parent: int) -> void:
	items[child]["parent"] = parent
	items[parent]["children"].append(child)


## Shelf packing, tallest first, wrapped at about 1.4 × the square root of the children's total area.
func _layout_region(index: int) -> void:
	var children: Array = items[index]["children"]
	var total_area: float = 0.0
	var widest: float = 0.0
	for child in children:
		if items[child]["kind"] == "region":
			_layout_region(child)
		var child_size: Vector2 = items[child]["size"]
		total_area += (child_size.x + GAP) * (child_size.y + GAP)
		widest = maxf(widest, child_size.x)
	children.sort_custom(func(a: int, b: int) -> bool: return items[a]["size"].y > items[b]["size"].y)
	var row_limit: float = maxf(widest, sqrt(total_area) * 1.4)
	var x: float = 0.0
	var y: float = 0.0
	var row_height: float = 0.0
	var content_width: float = 0.0
	for child in children:
		var child_size: Vector2 = items[child]["size"]
		if x > 0.0 and x + child_size.x > row_limit:
			x = 0.0
			y += row_height + GAP
			row_height = 0.0
		items[child]["local"] = Vector2(PAD + x, HEADER + PAD + y)
		x += child_size.x + GAP
		row_height = maxf(row_height, child_size.y)
		content_width = maxf(content_width, x - GAP)
	items[index]["size"] = Vector2(maxf(content_width, MIN_REGION_WIDTH) + PAD * 2.0, HEADER + PAD * 2.0 + y + row_height)


func _place_global(index: int) -> void:
	for child in items[index]["children"]:
		items[child]["global"] = items[index]["global"] + items[child]["local"]
		if items[child]["kind"] == "region":
			_place_global(child)


func _decide(index: int, previous: PackedByteArray, mask: PackedByteArray, near: Rect2, far: Rect2, zoom: float, open_px: float, close_px: float) -> void:
	var rect: Rect2 = global_rect(index)
	var on_screen_width: float = rect.size.x * zoom
	var open: bool
	if index == 0:
		open = true
	elif previous[index] == 1:
		open = on_screen_width >= close_px and rect.intersects(far)
	else:
		open = on_screen_width >= open_px and rect.intersects(near)
	mask[index] = 1 if open else 0
	if not open:
		return
	for child in items[index]["children"]:
		if items[child]["kind"] == "region":
			_decide(child, previous, mask, near, far, zoom, open_px, close_px)
