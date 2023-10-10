extends ScrollContainer
class_name BaseScroll

## What scene to spawn when generating scroll list
@export var prefab_to_spawn: PackedScene
@export var main_window: Node

var _item_holder: BoxContainer # Can be either H or V

func _ready():
	_item_holder = get_child(0)

## Used to spawn a child of the prefab defined, and pass in data in its 'setup' function
func spawn_list_item(data: Dictionary = {}) -> Node:
	var new_item = prefab_to_spawn.instantiate()
	_item_holder.add_child(new_item)
	new_item.setup(data, main_window)  # new item should have a setup function
	return new_item

## Delete child by positional index
func remove_child_by_index(index: int) -> void:
	if _item_holder.get_child_count() <= index:
		push_warning("Attempted to delete nonexistant child index from scrollbar. skipping...")
		return
	_item_holder.get_child(index).queue_free()

## Delete child by node name
func remove_child_by_name(child_name: StringName) -> void:
	var children: Array = _item_holder.get_children()
	for child in children:
		if child.name == child_name:
			child.queue_free()
			return
	push_warning("Attempted to delete nonexistant child %s from scrollbar. skipping..." % child_name)

## Deletes all children (list items)
func remove_all_children() -> void:
	var children: Array = _item_holder.get_children()
	for child in children:
		child.queue_free()

