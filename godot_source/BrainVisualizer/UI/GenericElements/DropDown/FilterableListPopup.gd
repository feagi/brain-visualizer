extends PopupPanel
class_name FilterableListPopup
## Lightweight popup list with a filter bar and selection callback.

signal item_chosen(payload: Variant)

const BASE_POPUP_SIZE: Vector2 = Vector2(320, 320)
const BASE_MARGIN: int = 8
const BASE_FONT_SIZE: int = 14

var _filter_line: LineEdit
var _item_list: ItemList
var _items: Array[Dictionary] = []
var _filtered_item_indices: Array[int] = []
var _selection_handler: Callable
## List ItemList base size from theme; filter uses the same scale so the bar matches the list body.
var _base_list_font_size: int = 0

## Wire UI and bind theme updates for consistent scaling.
func _ready() -> void:
	_filter_line = $MarginContainer/VBoxContainer/FilterLine
	_item_list = $MarginContainer/VBoxContainer/ItemList
	_filter_line.text_changed.connect(_on_filter_changed)
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_clicked.connect(_on_item_clicked)
	_item_list.item_activated.connect(_on_item_activated)
	_base_list_font_size = _get_theme_font_size_safe(_item_list)
	BV.UI.theme_changed.connect(_on_theme_changed)
	_on_theme_changed(BV.UI.loaded_theme)

## Populate and open the popup anchored to a control.
func open_with_items(anchor_control: Control, items: Array[Dictionary], selection_handler: Callable, placeholder_text: String) -> void:
	_items = items
	_selection_handler = selection_handler
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
	var popup_pos := Vector2(anchor_pos.x, anchor_pos.y + anchor_size.y)
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
		_selection_handler.call_deferred(payload)
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
	_filter_line.add_theme_font_size_override("font_size", list_size)
	_item_list.add_theme_font_size_override("font_size", list_size)


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
