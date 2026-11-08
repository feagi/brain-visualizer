extends RefCounted
class_name SchematicReachability
## Which items and mappings are related to one item, for the hover dim in the Circuit Schematic.
## Built once per [SchematicModel] from [member SchematicModel.mappings] (item-level, already resolved
## by [SchematicTreeBuilder]). Closed regions and classifiers are single merged nodes there, so a path
## through them is approximate: it follows the merged ends, not the areas inside.
## Related = everything reachable forward from the item + everything that reaches it backward, and
## only the mappings on those chains. A mapping is lit when both its ends are in the forward set
## (hovered item included) or both are in the backward set. With u->h, h->v and u->v, the u->v mapping
## is not on a chain through h, so it stays dim.

var _mappings: Array[PackedInt32Array] = []
var _forward: Dictionary = {} ## item -> PackedInt32Array of mapping indices leaving it
var _backward: Dictionary = {} ## item -> PackedInt32Array of mapping indices entering it


func _init(model: SchematicModel = null) -> void:
	if model == null:
		return
	_mappings = model.mappings
	for i in _mappings.size():
		var mapping: PackedInt32Array = _mappings[i]
		_add(_forward, mapping[0], i)
		_add(_backward, mapping[1], i)


## {"items": {item index: true}, "mappings": {mapping index: true}} related to [param item].
## The item itself is always included.
func related_to(item: int) -> Dictionary:
	var lit_items: Dictionary = {item: true}
	var lit_mappings: Dictionary = {}
	_walk(item, true, lit_items, lit_mappings)
	_walk(item, false, lit_items, lit_mappings)
	return {"items": lit_items, "mappings": lit_mappings}


func _walk(start: int, forward: bool, lit_items: Dictionary, lit_mappings: Dictionary) -> void:
	var adjacency: Dictionary = _forward if forward else _backward
	var seen: Dictionary = {start: true}
	var queue: Array[int] = [start]
	var head: int = 0
	while head < queue.size():
		var node: int = queue[head]
		head += 1
		for mapping_index in adjacency.get(node, PackedInt32Array()):
			lit_mappings[mapping_index] = true
			var other: int = _mappings[mapping_index][1 if forward else 0]
			lit_items[other] = true
			if not seen.has(other):
				seen[other] = true
				queue.append(other)


static func _add(adjacency: Dictionary, item: int, mapping_index: int) -> void:
	var list: PackedInt32Array = adjacency.get(item, PackedInt32Array())
	list.append(mapping_index)
	adjacency[item] = list
