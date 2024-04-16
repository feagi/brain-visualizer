extends VBoxContainer
class_name GenericTextIDScroll

signal item_selected(ID: Variant)

@export var enable_filter_box: bool = true
@export var setup_filter_by_name: bool = true
@export var button_selected_color: Color = Color.GRAY
@export var button_unselected_color: Color = Color.DIM_GRAY
@export var minimum_height_for_buttons: int = 0

var _text_button_prefab: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/GenericTextIDScroll/GenericScrollItemText.tscn")
var _filter_text: LineEdit
var _scroll_container: ScrollContainer
var _scroll_holder: BoxContainer
var _default: StyleBoxFlat
var _selected: StyleBoxFlat
var _cached_minimum_size: Vector2i

func _ready() -> void:
	_cached_minimum_size = custom_minimum_size
	_filter_text = $filter
	_scroll_container = get_child(1)
	_scroll_holder = _scroll_container.get_child(0)
	_default = StyleBoxFlat.new()
	_selected = StyleBoxFlat.new()
	_default.bg_color = button_unselected_color
	_selected.bg_color = button_selected_color
	_filter_text.placeholder_text = "Filter..."
	if setup_filter_by_name:
		_filter_text.text_changed.connect(filter_by_button_text)
	
	toggle_filter_text_box(enable_filter_box)
	_on_theme_change()
	BV.UI.theme_changed.connect(_on_theme_change)


## Adds single item to the list
func append_single_item(ID: Variant, text: StringName) -> void:
	var new_button: GenericScrollItemText = _text_button_prefab.instantiate()
	_scroll_holder.add_child(new_button)
	new_button.setup(ID, text, _default, _selected, minimum_height_for_buttons)
	new_button.selected.connect(_selection_proxy)
	new_button.custom_minimum_size = BV.UI.get_minimum_size_from_loaded_theme("Button_List")
	

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

## Selects a child item by ID, causes the button to emit its selection signal (unless item is not found)
func set_selected(ID_to_select: Variant) -> void:
	deselect_all()
	var index_to_select: int = _find_child_index_with_ID(ID_to_select)
	if index_to_select != -1:
		_scroll_holder.get_child(index_to_select).user_selected()
	else:
		return # if ID doesnt exist, keep all deselected

func get_button_by_ID(ID_to_select: Variant) -> GenericScrollItemText:
	var index_to_select: int = _find_child_index_with_ID(ID_to_select)
	if index_to_select != -1:
		return _scroll_holder.get_child(index_to_select)
	return null

func deselect_all() -> void:
	for child in _scroll_holder.get_children():
		child.user_deselected()

func delete_all() -> void:
	for child in _scroll_holder.get_children():
		child.queue_free()

func filter_by_button_text(searching_string: StringName) -> void:
	if searching_string == &"":
		revoke_filter()
		return
	for child in _scroll_holder.get_children():
		if child.text.to_lower().contains(searching_string.to_lower()):
			child.visible = true
		else:
			child.visible = false

func filter_by_button_text_whitelist(whitelist: PackedStringArray) -> void:
	for child in _scroll_holder.get_children():
		if FEAGIUtils.is_substring_in_array(whitelist, child.text):
			child.visible = true
		else:
			child.visible = false

func filter_by_IDs(whitelist: Array) -> void:
	for child in _scroll_holder.get_children():
		if child.ID in whitelist:
			child.visible = true
		else:
			child.visible = false

func revoke_filter() -> void:
	for child in _scroll_holder.get_children():
		child.visible = true

func toggle_filter_text_box(is_enabled_filter_box: bool) -> void:
	_filter_text.visible = is_enabled_filter_box

func _find_child_index_with_ID(searching_ID: Variant) -> int:
	for child in _scroll_holder.get_children():
		if child.ID == searching_ID:
			return child.get_index()
	push_error("UI: Unable to find child index with given ID!")
	return -1

func _selection_proxy(ID: Variant, index: int) -> void:
	_deselect_others(index)
	item_selected.emit(ID)

func _deselect_others(child_index_to_not_deselect: int) -> void:
	for child_index in _scroll_holder.get_child_count():
		if child_index == child_index_to_not_deselect:
			continue
		_scroll_holder.get_child(child_index).user_deselected()

func _on_theme_change(_new_theme: Theme = null) -> void:
	var min_size: Vector2i = BV.UI.get_minimum_size_from_loaded_theme("Button_List")
	for child in _scroll_holder.get_children():
		child.custom_minimum_size = min_size
	custom_minimum_size = _cached_minimum_size * BV.UI.loaded_theme_scale.x
