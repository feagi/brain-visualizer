extends ScrollContainer
class_name GenericTextIDScroll

signal item_selected(ID: Variant)

@export var button_selected_color: Color = Color.GRAY
@export var button_unselected_color: Color = Color.DIM_GRAY

var _text_button_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Elements/Scroll/GenericTextIDScroll/GenericScrollItemText.tscn")
var _scroll_holder: BoxContainer
var _default: StyleBoxFlat
var _selected: StyleBoxFlat

func _ready() -> void:
	_scroll_holder = get_child(0)
	_default = StyleBoxFlat.new()
	_selected = StyleBoxFlat.new()
	_default.bg_color = button_unselected_color
	_selected.bg_color = button_selected_color

## Adds single item to the list
func append_single_item(ID: Variant, text: StringName) -> void:
	var new_button: GenericScrollItemText = _text_button_prefab.instantiate()
	_scroll_holder.add_child(new_button)
	new_button.setup(ID, text, _default, _selected)
	new_button.selected.connect(_selection_proxy)

## Adds from an array of names and IDs. Array lengths MUST match
func append_from_arrays(IDs: Array, names: PackedStringArray) -> void:
	if len(IDs) != len(names):
		push_error("UI: Unable to populate text list due to mismatched ID and name array lengths! Skipping!")
		return
	for index in len(IDs):
		append_single_item(IDs[index], names[index])

## Removes a child item by ID
func remove_by_ID(ID_to_remove: Variant) -> void:
	var index_to_select: int = _find_child_index_with_ID(ID_to_remove)
	if index_to_select != -1:
		_scroll_holder.get_child(index_to_select).queue_free()

## Selects a child item by ID
func set_selected(ID_to_select: Variant) -> void:
	deselect_all()
	var index_to_select: int = _find_child_index_with_ID(ID_to_select)
	if index_to_select != -1:
		_scroll_holder.get_child(index_to_select).user_selected()


func deselect_all() -> void:
	for child in _scroll_holder.get_children():
		child.user_deselected()

func delete_all() -> void:
	for child in _scroll_holder.get_children():
		child.queue_free()

func _find_child_index_with_ID(searching_ID: Variant) -> int:
	for child in _scroll_holder.get_children():
		if child.ID == searching_ID:
			return child.get_index()
	push_error("UI: Unable to find child index with given ID!")
	return -1

func _selection_proxy(ID: Variant, _index: int) -> void:
	item_selected.emit(ID)


