extends BaseDraggableWindow
class_name WindowVisualVectorEdit
## Visual editor for vector connectivity rules. Multiple Z slices, click-to-toggle grid.

const WINDOW_NAME: StringName = &"visual_vector_edit"
const GUIDE_FILE := "vector_connectivity.md"
const GUIDE_HEADING := "Visual editor"

var _grid: VectorEditGrid
var _z_prev: Button
var _z_next: Button
var _z_spin: SpinBox
var _grid_minus: Button
var _grid_plus: Button
var _rotate_ccw: Button
var _rotate_cw: Button
var _shrink: Button
var _enlarge: Button
var _copy_slice: Button
var _copy_all: Button
var _paste: Button
var _clear: Button
var _undo: Button
var _redo: Button
var _hidden_note: Label
var _cancel_button: Button
var _save_button: Button
var _on_save: Callable
var _z_min: int = -10
var _z_max: int = 10
## True after a mouse press landed inside this window; any press outside clears it.
var _pointer_inside: bool = false
var _clip_text_snapshot: String = ""
var _clip_snapshot_valid: bool = false
var _clip_payload: Dictionary = {}

func _ready() -> void:
	super()
	_grid = $WindowPanel/WindowMargin/WindowInternals/GridContainer/VectorEditGrid
	_z_prev = $WindowPanel/WindowMargin/WindowInternals/ZRow/ZPrev
	_z_next = $WindowPanel/WindowMargin/WindowInternals/ZRow/ZNext
	_z_spin = $WindowPanel/WindowMargin/WindowInternals/ZRow/ZSpin
	var tools: String = "WindowPanel/WindowMargin/WindowInternals/ToolRow/"
	_grid_minus = get_node(tools + "GridGroup/GridMinus")
	_grid_plus = get_node(tools + "GridGroup/GridPlus")
	_rotate_ccw = get_node(tools + "RotateGroup/RotateCcw")
	_rotate_cw = get_node(tools + "RotateGroup/RotateCw")
	_shrink = get_node(tools + "ScaleGroup/Shrink")
	_enlarge = get_node(tools + "ScaleGroup/Enlarge")
	_copy_slice = get_node(tools + "ClipGroup/CopySlice")
	_copy_all = get_node(tools + "ClipGroup/CopyAll")
	_paste = get_node(tools + "ClipGroup/Paste")
	_clear = get_node(tools + "ClearGroup/Clear")
	_undo = get_node(tools + "HistoryGroup/Undo")
	_redo = get_node(tools + "HistoryGroup/Redo")
	_hidden_note = $WindowPanel/WindowMargin/WindowInternals/HiddenNote
	_cancel_button = $WindowPanel/WindowMargin/WindowInternals/ButtonRow/Cancel
	_save_button = $WindowPanel/WindowMargin/WindowInternals/ButtonRow/Save
	($WindowPanel/WindowMargin/WindowInternals/ButtonRow/Guide as Button).pressed.connect(_on_guide_pressed)

	_grid.setup()
	_z_prev.pressed.connect(_on_z_prev)
	_z_next.pressed.connect(_on_z_next)
	_z_spin.value_changed.connect(_on_z_spin_changed)
	_grid_minus.pressed.connect(_grid.step_radius.bind(-1))
	_grid_plus.pressed.connect(_grid.step_radius.bind(1))
	_rotate_ccw.pressed.connect(_grid.rotate_slice.bind(false))
	_rotate_cw.pressed.connect(_grid.rotate_slice.bind(true))
	_shrink.pressed.connect(_grid.scale_slice.bind(false))
	_enlarge.pressed.connect(_grid.scale_slice.bind(true))
	_copy_slice.pressed.connect(_copy.bind(VectorClipboardPayload.SCOPE_SLICE))
	_copy_all.pressed.connect(_copy.bind(VectorClipboardPayload.SCOPE_ALL))
	_paste.pressed.connect(_paste_from_clipboard)
	_clear.pressed.connect(_grid.clear_slice)
	_undo.pressed.connect(_grid.undo)
	_redo.pressed.connect(_grid.redo)
	_grid.view_changed.connect(_refresh_tools)
	_refresh_tools()
	_cancel_button.pressed.connect(close_window)
	_save_button.pressed.connect(_on_save_pressed)

func setup(initial_vectors: Array[Vector3i], on_save: Callable) -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Visual Edit - Vectors"
	_on_save = on_save

	var selection: Dictionary = {}
	var z_vals: Array[int] = []
	for v in initial_vectors:
		selection[_vec_key(v.x, v.y, v.z)] = true
		if v.z not in z_vals:
			z_vals.append(v.z)

	z_vals.sort()
	if !z_vals.is_empty():
		_z_min = mini(_z_min, z_vals[0])
		_z_max = maxi(_z_max, z_vals[z_vals.size() - 1])

	_z_spin.min_value = _z_min
	_z_spin.max_value = _z_max
	var initial_z: int = z_vals[0] if !z_vals.is_empty() else 0
	_z_spin.value = initial_z
	_grid.set_full_selection(selection)
	_grid.set_current_z(initial_z)
	_refresh_clipboard()

func _refresh_tools() -> void:
	_grid_minus.disabled = not _grid.can_radius_down()
	_grid_plus.disabled = not _grid.can_radius_up()
	var empty: bool = _grid.slice_cell_count() == 0
	_rotate_ccw.disabled = empty
	_rotate_cw.disabled = empty
	_shrink.disabled = empty
	_enlarge.disabled = empty or not _grid.slice_can_enlarge()
	_copy_slice.disabled = empty
	_copy_all.disabled = _grid.full_cell_count() == 0
	_clear.disabled = empty
	_paste.disabled = _clip_vectors().is_empty()
	_undo.disabled = not _grid.can_undo()
	_redo.disabled = not _grid.can_redo()
	var n: int = _grid.hidden_count()
	if n == 0:
		_hidden_note.text = ""
	elif n == 1:
		_hidden_note.text = "1 vector on this Z slice is outside the visible grid"
	else:
		_hidden_note.text = "%d vectors on this Z slice are outside the visible grid" % n

func _vec_key(x: int, y: int, z: int) -> String:
	return str(x) + "," + str(y) + "," + str(z)

func _on_z_prev() -> void:
	var v: float = _z_spin.value
	if v > _z_spin.min_value:
		_z_spin.value = v - 1
	else:
		_z_spin.min_value = int(v) - 1
		_z_spin.value = v - 1

func _on_z_next() -> void:
	var v: float = _z_spin.value
	if v < _z_spin.max_value:
		_z_spin.value = v + 1
	else:
		_z_spin.max_value = int(v) + 1
		_z_spin.value = v + 1

func _on_z_spin_changed(_new_value: float) -> void:
	_grid.set_current_z(int(_z_spin.value))

func _on_save_pressed() -> void:
	var sel: Dictionary = _grid.get_full_selection()
	var vectors: Array[Vector3i] = []
	for key in sel.keys():
		var parts: PackedStringArray = key.split(",", false)
		if parts.size() == 3:
			vectors.append(Vector3i(int(parts[0]), int(parts[1]), int(parts[2])))
	vectors.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z: return a.z < b.z
		if a.y != b.y: return a.y < b.y
		return a.x < b.x
	)
	_on_save.call(vectors)
	close_window()

# ---------- Clipboard and keys ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _paste != null:
		_refresh_clipboard()

func _clip_vectors() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if _clip_payload.has("vectors"):
		out = _clip_payload["vectors"]
	return out

## Re-reads the system clipboard; decodes only when its text changed (or when forced).
func _refresh_clipboard(force: bool = false) -> void:
	var text: String = DisplayServer.clipboard_get()
	if _clip_snapshot_valid and not force and text == _clip_text_snapshot:
		return
	_set_clipboard_snapshot(text)

func _set_clipboard_snapshot(text: String) -> void:
	_clip_text_snapshot = text
	_clip_snapshot_valid = true
	_clip_payload = VectorClipboardPayload.decode(text)
	_refresh_tools()

func _copy(scope: String) -> void:
	var vectors: Array[Vector3i] = _grid.slice_vectors() if scope == VectorClipboardPayload.SCOPE_SLICE else _grid.all_vectors()
	if vectors.is_empty():
		return  # leave the clipboard untouched
	var text: String = VectorClipboardPayload.encode(scope, vectors)
	DisplayServer.clipboard_set(text)
	_set_clipboard_snapshot(text)

func _paste_from_clipboard() -> void:
	_refresh_clipboard(true)
	var vectors: Array[Vector3i] = _clip_vectors()
	if vectors.is_empty():
		return
	var scope: String = String(_clip_payload["scope"])
	if scope == VectorClipboardPayload.SCOPE_ALL:
		_widen_z_range(vectors)
	_grid.paste_vectors(scope, vectors)

func _widen_z_range(vectors: Array[Vector3i]) -> void:
	var lo: int = vectors[0].z
	var hi: int = vectors[0].z
	for v in vectors:
		lo = mini(lo, v.z)
		hi = maxi(hi, v.z)
	if lo < _z_spin.min_value:
		_z_spin.min_value = lo
	if hi > _z_spin.max_value:
		_z_spin.max_value = hi

## Active = top window AND the last mouse press landed inside it.
func _is_editor_active() -> bool:
	if not _pointer_inside or not is_visible_in_tree():
		return false
	var parent: Node = get_parent()
	return parent != null and parent.get_child(-1) == self

func _is_editor_top_window() -> bool:
	var parent: Node = get_parent()
	return parent != null and parent.get_child(-1) == self

func _on_guide_pressed() -> void:
	if BV == null or BV.WM == null:
		return
	BV.WM.spawn_guide_page(GUIDE_FILE, GUIDE_HEADING)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			var inside: bool = get_global_rect().has_point(mb.position)
			if inside and not _pointer_inside:
				_refresh_clipboard()
			_pointer_inside = inside
			# A press on a child control is consumed there and never reaches _gui_input,
			# so raise the window here or its shortcuts stay dead behind another window.
			if inside and not _is_editor_top_window():
				bring_window_to_top()
	elif event is InputEventKey and _is_editor_active():
		if _handle_key(event as InputEventKey):
			accept_event()
			return
	super._input(event)

## Returns true when the key is ours (even if it did nothing) so it never reaches the 3D view.
func _handle_key(key: InputEventKey) -> bool:
	if not key.pressed:
		return false
	if GenomeHistory.focus_blocks_history_shortcut(get_viewport().gui_get_focus_owner()):
		return false  # a text field keeps its own editing keys
	var command: bool = key.ctrl_pressed or key.meta_pressed
	if not command or key.alt_pressed:
		return false
	var action: StringName = GenomeHistory.history_shortcut(key.keycode, command, key.shift_pressed, key.alt_pressed, true, false)
	if action == &"" and key.keycode == KEY_Y and not key.shift_pressed:
		action = &"redo"
	if action == &"" and not key.shift_pressed:
		if key.keycode == KEY_C:
			action = &"copy"
		elif key.keycode == KEY_V:
			action = &"paste"
	if action == &"":
		return false
	if key.echo:
		return true
	match action:
		&"undo":
			_grid.undo()
		&"redo":
			_grid.redo()
		&"copy":
			_copy(VectorClipboardPayload.SCOPE_SLICE)
		&"paste":
			_paste_from_clipboard()
	return true
