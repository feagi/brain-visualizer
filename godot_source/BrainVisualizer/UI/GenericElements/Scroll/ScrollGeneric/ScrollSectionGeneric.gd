extends ScrollContainer
class_name ScrollSectionGeneric
## Allows for creating lists of a control (with IDs and passable references)

const PREFAB_ITEM: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGeneric/ScrollSectionGenericItem.tscn")

signal user_pressed_delete_item(ref: ScrollSectionGenericItem)

var _container: BoxContainer
var _lookup: Dictionary = {} # Key'd by user definable keys, data is the relevant [ScrollSectionGenericItem]

func _ready():
	_container = $BoxContainer

func add_item(control: Control, lookup_key: Variant, enable_delete_button: bool = true, delete_button_deletes_item: bool = true) -> ScrollSectionGenericItem:
	if lookup_key in _lookup.keys():
		push_error("UI: Unable to add item with existing key!")
		return null
	var item: ScrollSectionGenericItem = PREFAB_ITEM.instantiate()
	item.setup(control, lookup_key, enable_delete_button, delete_button_deletes_item)
	_container.add_child(item)
	_lookup[lookup_key] = item
	item.deleted.connect(_user_pressing_delete_item)
	return item

#TODO
func define_empty_notice_control(empty_control: Control) -> void:
	pass

func is_containing_key(lookup_key: Variant) -> bool:
	return lookup_key in _lookup.keys()

func attempt_retrieve_item(lookup_key: Variant) -> ScrollSectionGenericItem:
	if !(lookup_key in _lookup.keys()):
		return null
	return _lookup[lookup_key]

func attempt_remove_item(lookup_key: Variant) -> void:
	if !(lookup_key in _lookup.keys()):
		push_error("UI: Unable to remove nonexistant item!")
	_lookup[lookup_key].queue_free()
	_lookup.erase(lookup_key)

func get_key_array() -> Array:
	return _lookup.keys()

func remove_all_items() -> void:
	_lookup = {}
	for child in _container.get_children():
		child.queue_free()

func _user_pressing_delete_item(ref: ScrollSectionGenericItem) -> void:
	if ref.auto_delete_enabled:
		attempt_remove_item(ref.lookup_key)
	user_pressed_delete_item.emit(ref)
