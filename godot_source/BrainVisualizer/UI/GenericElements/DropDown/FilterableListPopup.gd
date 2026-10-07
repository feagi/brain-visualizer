extends PopupPanel
class_name FilterableListPopup
## Lightweight popup list with a filter bar and selection callback.

signal item_chosen(payload: Variant)

const BASE_POPUP_SIZE: Vector2 = Vector2(320, 320)
const BASE_MARGIN: int = 8
const BASE_FONT_SIZE: int = 14
const ADD_NEW_TEXT := "Add new"
## Steps above the list font so Add new reads as the action, not another list row.
const ADD_NEW_FONT_EXTRA: int = 4

var _add_row: HBoxContainer
var _guide_button: TextureButton
var _add_new_button: Button
var _filter_line: LineEdit
var _item_list: ItemList
var _items: Array[Dictionary] = []
var _filtered_item_indices: Array[int] = []
var _selection_handler: Callable
var _add_handler: Callable = Callable()
var _guide_file: String = ""
var _guide_heading: String = ""
## Pulls the popup up over the anchor so a hover can cross into the list.
var _anchor_overlap_px: int = 0
## List ItemList base size from theme; filter uses the same scale so the bar matches the list body.
var _base_list_font_size: int = 0

## The add action is shown only when the opener supplied a handler.
static func should_show_add_new_button(add_handler_valid: bool) -> bool:
	return add_handler_valid


## The info button sits left of Add new and only when that list has a guide page.
static func should_show_guide_button(add_button_visible: bool, guide_file: String) -> bool:
	return add_button_visible and not guide_file.strip_edges().is_empty()


## The info control is a square whose side matches the Add new button height.
static func guide_button_side(add_button_height: int) -> int:
	return maxi(0, add_button_height)


## Add new uses a larger face than the filter list so it stays the first thing in the menu.
static func add_new_font_size(list_font_size: int) -> int:
	return list_font_size + ADD_NEW_FONT_EXTRA


## Wire UI and bind theme updates for consistent scaling.
func _ready() -> void:
	_add_row = $MarginContainer/VBoxContainer/AddRow
	_guide_button = $MarginContainer/VBoxContainer/AddRow/GuideButton
	_add_new_button = $MarginContainer/VBoxContainer/AddRow/AddNew
	_filter_line = $MarginContainer/VBoxContainer/FilterLine
	_item_list = $MarginContainer/VBoxContainer/ItemList
	_add_new_button.text = ADD_NEW_TEXT
	_guide_button.tooltip_text = ""
	_guide_button.pressed.connect(_on_guide_pressed)
	_add_new_button.pressed.connect(_on_add_new_pressed)
	_filter_line.text_changed.connect(_on_filter_changed)
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_clicked.connect(_on_item_clicked)
	_item_list.item_activated.connect(_on_item_activated)
	_base_list_font_size = _get_theme_font_size_safe(_item_list)
	BV.UI.theme_changed.connect(_on_theme_changed)
	_on_theme_changed(BV.UI.loaded_theme)

## Populate and open the popup anchored to a control.
func open_with_items(anchor_control: Control, items: Array[Dictionary], selection_handler: Callable, placeholder_text: String, anchor_overlap_px: int = 0, add_handler: Callable = Callable(), guide_file: String = "", guide_heading: String = "") -> void:
	_items = items
	_selection_handler = selection_handler
	_add_handler = add_handler
	_guide_file = guide_file.strip_edges()
	_guide_heading = guide_heading.strip_edges()
	var show_add := should_show_add_new_button(add_handler.is_valid())
	_add_new_button.visible = show_add
	_guide_button.visible = should_show_guide_button(show_add, _guide_file)
	_add_row.visible = show_add
	_anchor_overlap_px = anchor_overlap_px
	_filter_line.placeholder_text = placeholder_text
	_filter_line.text = ""
	_apply_filter("")
	_reparent_to_root_viewport()
	_popup_at_control(anchor_control)
	_filter_line.grab_focus()

## Apply the filter text to the item list.
func _apply_filter(filter_text: String) -> void:
	_item_list.clear()
	_filtered_item_indices.clear()
	var query := filter_text.strip_edges().to_lower()
	for i in range(_items.size()):
		var label := String(_items[i].get("label", ""))
		if query == "" or label.to_lower().find(query) >= 0:
			_item_list.add_item(label)
			_filtered_item_indices.append(i)

## Open the popup under the given control, clamped to the viewport.
func _popup_at_control(anchor_control: Control) -> void:
	if anchor_control == null:
		return
	var viewport_rect := get_tree().root.get_visible_rect()
	var popup_size := _get_scaled_popup_size()
	var anchor_pos := _get_anchor_screen_position(anchor_control)
	var anchor_size := anchor_control.size
	var popup_pos := Vector2(anchor_pos.x, anchor_pos.y + anchor_size.y - float(_anchor_overlap_px))
	if popup_pos.x + popup_size.x > viewport_rect.end.x:
		popup_pos.x = viewport_rect.end.x - popup_size.x
	if popup_pos.y + popup_size.y > viewport_rect.end.y:
		popup_pos.y = anchor_pos.y - popup_size.y
	popup_pos.x = maxi(int(viewport_rect.position.x), int(popup_pos.x))
	popup_pos.y = maxi(int(viewport_rect.position.y), int(popup_pos.y))
	popup(Rect2(popup_pos, popup_size))

## Return popup size scaled to the current UI theme.
func _get_scaled_popup_size() -> Vector2:
	var scale := Vector2(1.0, 1.0)
	if BV.UI and BV.UI.loaded_theme_scale:
		scale = BV.UI.loaded_theme_scale
	var scaled := BASE_POPUP_SIZE * scale
	var view_rect := get_tree().root.get_visible_rect()
	if view_rect:
		scaled.x = min(scaled.x, view_rect.size.x - (BASE_MARGIN * 2))
		scaled.y = min(scaled.y, view_rect.size.y - (BASE_MARGIN * 2))
	return scaled

## Ensure the popup lives under the root viewport.
func _reparent_to_root_viewport() -> void:
	var root_viewport := get_tree().root
	if get_parent() == root_viewport:
		return
	if get_parent() != null:
		get_parent().remove_child(self)
	root_viewport.add_child(self)


## Convert the anchor control position into root viewport coordinates.
func _get_anchor_screen_position(anchor_control: Control) -> Vector2:
	var anchor_pos := anchor_control.get_global_position()
	var anchor_viewport := anchor_control.get_viewport()
	if anchor_viewport is SubViewport:
		var container := anchor_viewport.get_parent()
		if container is SubViewportContainer:
			anchor_pos += (container as SubViewportContainer).get_global_position()
	return anchor_pos

## Open the guide for this list, then close so the guide window is not covered by the list.
func _on_guide_pressed() -> void:
	var guide_file := _guide_file
	var guide_heading := _guide_heading
	hide()
	if guide_file.is_empty() or BV == null or BV.WM == null:
		return
	BV.WM.spawn_guide_page(guide_file, guide_heading)


## Run the opener's add action, then close so the create window is not covered by the list.
func _on_add_new_pressed() -> void:
	var handler := _add_handler
	hide()
	if handler.is_valid():
		handler.call()


## Handle filter input changes.
func _on_filter_changed(new_text: String) -> void:
	_apply_filter(new_text)

## Handle item selection and emit the payload.
func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _filtered_item_indices.size():
		return
	var item_index := _filtered_item_indices[index]
	var payload = _items[item_index].get("payload", null)
	if _selection_handler.is_valid():
		_selection_handler.call(payload)
	item_chosen.emit(payload)
	hide()


## Handle list item click (always trigger selection behavior).
func _on_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_on_item_selected(index)


## Handle list item activation (keyboard/enter).
func _on_item_activated(index: int) -> void:
	_on_item_selected(index)

## Sync theme and apply consistent padding.
func _on_theme_changed(_new_theme: Theme) -> void:
	theme = BV.UI.loaded_theme
	$MarginContainer.add_theme_constant_override("margin_left", BASE_MARGIN)
	$MarginContainer.add_theme_constant_override("margin_top", BASE_MARGIN)
	$MarginContainer.add_theme_constant_override("margin_right", BASE_MARGIN)
	$MarginContainer.add_theme_constant_override("margin_bottom", BASE_MARGIN)
	_apply_scaled_fonts()


## Apply font sizes based on the current UI scale (filter matches list; LineEdit theme base is often oversized).
func _apply_scaled_fonts() -> void:
	var scale := 1.0
	if BV.UI and BV.UI.loaded_theme_scale:
		scale = BV.UI.loaded_theme_scale.x
	var list_size := _scale_font_size(_base_list_font_size, scale) + 1
	_add_new_button.add_theme_font_size_override("font_size", add_new_font_size(list_size))
	_emphasize_add_new_button()
	_filter_line.add_theme_font_size_override("font_size", list_size)
	_item_list.add_theme_font_size_override("font_size", list_size)


## Paint Add new with the button hover fill and the theme button height so it sits above the filter.
func _emphasize_add_new_button() -> void:
	var hover_style := _add_new_button.get_theme_stylebox(&"hover")
	var pressed_style := _add_new_button.get_theme_stylebox(&"pressed")
	if hover_style != null:
		_add_new_button.add_theme_stylebox_override(&"normal", hover_style)
	if pressed_style != null:
		_add_new_button.add_theme_stylebox_override(&"hover", pressed_style)
		_add_new_button.add_theme_stylebox_override(&"pressed", pressed_style)
	var button_height := 0
	if theme != null and theme.has_constant(&"size_y", &"Button"):
		button_height = theme.get_constant(&"size_y", &"Button")
	if button_height > 0:
		_add_new_button.custom_minimum_size.y = button_height
		var side := guide_button_side(button_height)
		_guide_button.custom_minimum_size = Vector2(side, side)


## Safely get a control's base font size.
func _get_theme_font_size_safe(control: Control) -> int:
	if control == null:
		return BASE_FONT_SIZE
	var size := control.get_theme_font_size("font_size")
	if size <= 0:
		return BASE_FONT_SIZE
	return size


## Scale a base font size with clamping.
func _scale_font_size(base_size: int, scale: float) -> int:
	return maxi(8, int(round(float(base_size) * scale)))
