extends ScrollContainer
class_name BaseScroll

signal internal_add_button_pressed()

## What scene to spawn when generating scroll list
@export var prefab_to_spawn: PackedScene
@export var main_window: Node
@export var enable_button_notice_when_list_is_empty: bool = false
@export var button_notice_text: StringName
@export var top_gap: int = 8
@export var bottom_gap: int = 8

var _item_holder: BoxContainer # Can be either H or V
var _add_button_container: BoxContainer

func _ready():
	_item_holder = get_child(0)
	_add_button_container = $VBoxContainer/add_button_notice
	$VBoxContainer/add_button_notice/Button.text = button_notice_text
	_add_button_container.visible = enable_button_notice_when_list_is_empty
	$VBoxContainer/add_button_notice/gap.custom_minimum_size.y = top_gap
	$VBoxContainer/add_button_notice/gap2.custom_minimum_size.y = bottom_gap
	if enable_button_notice_when_list_is_empty:
		# Binds are used for the offset value, given that these signals fire before the node actually left, so that the get_number_of_children() call will be incorrect by 1 in either direction
		_item_holder.child_exiting_tree.connect( _show_empty_button_if_empty.bind(-1))
		_item_holder.child_entered_tree.connect( _show_empty_button_if_empty.bind(1))

## Used to spawn a child of the prefab defined, and pass in data in its 'setup' function
func spawn_list_item(data: Dictionary = {}) -> Node:
	var new_item = prefab_to_spawn.instantiate()
	_item_holder.add_child(new_item)
	new_item.setup(data, main_window)  # new item should have a setup function
	_add_button_container.visible = false
	return new_item

## Delete child by positional index
func remove_child_by_index(index: int) -> void:
	if _item_holder.get_child_count() <= index:
		push_warning("Attempted to delete nonexistant child index from scrollbar. skipping...")
		return
	_item_holder.get_child(index + 1).queue_free()
	
	_add_button_container.visible = true

## Delete child by node name
func remove_child_by_name(child_name: StringName) -> void:
	var children: Array = get_children_as_list()
	for child in children:
		if child.name == child_name:
			child.queue_free()
			
			return
	push_warning("Attempted to delete nonexistant child %s from scrollbar. skipping..." % child_name)

## Deletes all children (list items)
func remove_all_children() -> void:
	var children: Array = get_children_as_list()
	for child in children:
		child.queue_free()
	if enable_button_notice_when_list_is_empty:
		_add_button_container.visible = true

## Gets number of list elements (ignores button notice)
func get_number_of_children() -> int:
	return len(_item_holder.get_children()) - 1
	
func get_children_as_list() -> Array[Node]:
	var output: Array[Node] = _item_holder.get_children()
	output.pop_front()
	return output

func _add_button_proxy() -> void:
	internal_add_button_pressed.emit()

func _show_empty_button_if_empty(_irrelevant, offset: int) -> void:
	_add_button_container.visible = get_number_of_children() + offset == 0
