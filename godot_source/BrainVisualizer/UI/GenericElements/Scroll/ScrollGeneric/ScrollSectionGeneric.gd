extends ScrollContainer
class_name ScrollSectionGeneric
## Allows for creating lists of a control (with IDs and passable references)

const DEFAULT_BUTTON_THEME_VARIANT: StringName = "Button_List"
const PREFAB_ITEM: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGeneric/ScrollSectionGenericItem.tscn")
const PREFAB_BUTTON: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGeneric/Prefab_Items/ScrollSectionTextButton.tscn")
const PREFAB_BUTTON_WITH_DELETE: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGeneric/Prefab_Items/ScrollSectionTextButtonWithDelete.tscn")
const PREFAB_BUTTON_WITH_EDIT: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGeneric/Prefab_Items/ScrollSectionTextButtonWithEdit.tscn")

var _container: BoxContainer
var _lookup: Dictionary = {} # Key'd by user definable keys, data is the relevant [ScrollSectionGenericItem]
var _scale_theme_applier: ScaleThemeApplier

func _ready():
	_container = $BoxContainer
	_scale_theme_applier = ScaleThemeApplier.new()
	var not_search: Array[Node] = []
	_scale_theme_applier.setup(self, not_search, BV.UI.loaded_theme)

## Allows the addition of any control as a list item
func add_generic_item(control: Control, lookup_key: Variant, friendly_name: StringName) -> ScrollSectionGenericItem:
	if lookup_key in _lookup.keys():
		push_error("UI: Unable to add item with existing key!")
		return null
	var item: ScrollSectionGenericItem = PREFAB_ITEM.instantiate()
	item.setup(control, lookup_key, friendly_name)
	_container.add_child(item)
	if lookup_key != null: # we dont put null keys in the lookup dictionary, under the assumption the user knows what they are doing
		_lookup[lookup_key] = item
	_scale_theme_applier.search_for_matching_children(item)
	_scale_theme_applier.update_theme_customs(BV.UI.loaded_theme) #TODO VERY BAD
	return item

## Allows the addition text button with a label
func add_text_button(lookup_key: Variant, text: StringName, button_action: Callable, theme_variant: StringName = DEFAULT_BUTTON_THEME_VARIANT) -> ScrollSectionGenericItem:
	var prefab: HBoxContainer = PREFAB_BUTTON.instantiate()
	var button: Button = prefab.get_node("ScrollSectionTextButton")
	button.text = text
	if !button_action.is_null():
		button.pressed.connect(button_action)
	button.theme_type_variation = theme_variant
	return add_generic_item(prefab, lookup_key, text)

## Allows the addition text button with a label that can be deleted
func add_text_button_with_delete(lookup_key: Variant, text: StringName, button_action: Callable, theme_variant: StringName = DEFAULT_BUTTON_THEME_VARIANT, enable_auto_delete: bool = true) -> ScrollSectionGenericItem:
	var prefab: HBoxContainer = PREFAB_BUTTON_WITH_DELETE.instantiate()
	var button: Button = prefab.get_node("Text")
	var delete: TextureButton = prefab.get_node("Delete")
	button.text = text
	if !button_action.is_null():
		button.pressed.connect(button_action)
	button.theme_type_variation = theme_variant
	if enable_auto_delete:
		delete.pressed.connect(prefab.queue_free)
	return add_generic_item(prefab, lookup_key, text)

## Allows the addition text button with a label with a seperate edit button
func add_text_button_with_edit(lookup_key: Variant, text: StringName, button_action: Callable, edit_button_action: Callable, theme_variant: StringName = DEFAULT_BUTTON_THEME_VARIANT) -> ScrollSectionGenericItem:
	var prefab: HBoxContainer = PREFAB_BUTTON_WITH_EDIT.instantiate()
	var button: Button = prefab.get_node("Text")
	var edit: TextureButton = prefab.get_node("Edit")
	button.text = text
	if !button_action.is_null():
		button.pressed.connect(button_action)
	button.theme_type_variation = theme_variant
	edit.pressed.connect(edit_button_action)
	return add_generic_item(prefab, lookup_key, text)

#TODO
func define_empty_notice_control(empty_control: Control) -> void:
	pass

## Returns if a certain lookup key is stored in ehre
func is_containing_key(lookup_key: Variant) -> bool:
	return lookup_key in _lookup.keys()

## Attempts to return the root [ScrollSectionGenericItem] by lookup key, if not found returns null
func attempt_retrieve_item(lookup_key: Variant) -> ScrollSectionGenericItem:
	if !(lookup_key in _lookup.keys()):
		return null
	return _lookup[lookup_key]

## Attempts to remove the root [ScrollSectionGenericItem] by its lookup key. if it doesnt exist prints an error and continues
func attempt_remove_item(lookup_key: Variant) -> void:
	if !(lookup_key in _lookup.keys()):
		push_error("UI: Unable to remove nonexistant item!")
	_lookup[lookup_key].queue_free()
	_lookup.erase(lookup_key)

## Runs the set highlighting function of the root [ScrollSectionGenericItem] by its lookup key. if it doesnt exist prints an error and continues
func set_highlighting(lookup_key: Variant, is_highlighted: bool) -> void:
	var item: ScrollSectionGenericItem = attempt_retrieve_item(lookup_key)
	if item == null:
		push_error("Unknown lookup key, skipping setting highlighting!")
		return
	item.set_highlighting(is_highlighted)

func get_key_array() -> Array:
	return _lookup.keys()

## Deletes all items
func remove_all_items() -> void:
	_lookup = {}
	for child in _container.get_children():
		child.queue_free()

## Hide whatever does (or does not) contain the fiven filter string, in its friendly_name tag
func filter_by_friendly_name(filter: StringName, is_filter_pass: bool = true) -> void:
	for item: ScrollSectionGenericItem in _lookup.values():
		if filter.contains(item.name_tag):
			item.visible = is_filter_pass
		else:
			item.visible = !is_filter_pass

## Toggles the visiblity of all given items. Uses their keys
func toggle_all_visiblity(show: bool) -> void:
	for item: ScrollSectionGenericItem in _lookup.values():
		item.visible = show

## Ignoring the key system, directly gets all the spawned rows of the scroll section
func get_all_spawned_children_of_container() -> Array[ScrollSectionGenericItem]:
	var output: Array[ScrollSectionGenericItem]
	for child in _container.get_children():
		if child is ScrollSectionGenericItem:
			output.append(child)
	return output
