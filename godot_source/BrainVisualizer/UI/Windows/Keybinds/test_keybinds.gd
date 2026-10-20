extends SceneTree
## The shortcuts window opens on bare K and lists the real keybinds.
## Run: godot --headless --path godot_source --script res://BrainVisualizer/UI/Windows/Keybinds/test_keybinds.gd
##
## Scripts are loaded inside [_initialize] so autoload names exist before they compile.

const _CATALOG_PATH := "res://BrainVisualizer/UI/Windows/Keybinds/KeybindCatalog.gd"
const _WINDOW_PATH := "res://BrainVisualizer/UI/Windows/Keybinds/WindowKeybinds.gd"

var _catalog: GDScript
var _window: GDScript


func _initialize() -> void:
	_catalog = load(_CATALOG_PATH) as GDScript
	_window = load(_WINDOW_PATH) as GDScript
	if _catalog == null or not _catalog.can_instantiate():
		push_error("Keybind catalog did not compile")
		quit(1)
		return
	if _window == null or not _window.can_instantiate():
		push_error("Keybinds window did not compile")
		quit(1)
		return
	var failures := 0
	failures += _test_shortcut()
	failures += _test_text_focus()
	failures += _test_catalog()
	failures += _test_window_placement()
	failures += _test_resize()
	if failures == 0:
		print("Keybind tests: PASS")
		quit(0)
	else:
		push_error("Keybind tests: FAIL (%d)" % failures)
		quit(1)


func _test_shortcut() -> int:
	if not _catalog.is_keybinds_shortcut(KEY_K, KEY_NONE, false, false, false, true, false):
		push_error("K should open the shortcuts window")
		return 1
	if not _catalog.is_keybinds_shortcut(KEY_NONE, KEY_K, false, false, false, true, false):
		push_error("physical K should open the shortcuts window")
		return 1
	if _catalog.is_keybinds_shortcut(KEY_K, KEY_K, true, false, false, true, false):
		push_error("Ctrl/Cmd+K should not open the shortcuts window")
		return 1
	if _catalog.is_keybinds_shortcut(KEY_K, KEY_K, false, true, false, true, false):
		push_error("Shift+K should not open the shortcuts window")
		return 1
	if _catalog.is_keybinds_shortcut(KEY_K, KEY_K, false, false, true, true, false):
		push_error("Alt+K should not open the shortcuts window")
		return 1
	if _catalog.is_keybinds_shortcut(KEY_K, KEY_K, false, false, false, true, true):
		push_error("a key repeat should not toggle the shortcuts window")
		return 1
	if _catalog.is_keybinds_shortcut(KEY_K, KEY_K, false, false, false, false, false):
		push_error("releasing K should not toggle the shortcuts window")
		return 1
	if _catalog.is_keybinds_shortcut(KEY_S, KEY_S, false, false, false, true, false):
		push_error("S should not open the shortcuts window")
		return 1
	return 0


func _test_text_focus() -> int:
	if not _catalog.focus_blocks_keybinds(LineEdit.new()):
		push_error("a line edit should keep the letter K")
		return 1
	if not _catalog.focus_blocks_keybinds(TextEdit.new()):
		push_error("a text edit should keep the letter K")
		return 1
	if _catalog.focus_blocks_keybinds(null):
		push_error("no focus owner should still allow K")
		return 1
	if _catalog.focus_blocks_keybinds(Control.new()):
		push_error("a plain control should still allow K")
		return 1
	return 0


func _test_catalog() -> int:
	var rows: Array = _catalog.entries()
	if rows.is_empty():
		push_error("the shortcuts table is empty")
		return 1
	var seen: Dictionary = {}
	var sections: Array[String] = []
	var has_open := false
	var has_search := false
	var has_undo := false
	var has_views := false
	for entry in rows:
		var keys := String(entry.get(_catalog.KEY_KEYS, "")).strip_edges()
		var action := String(entry.get(_catalog.KEY_ACTION, "")).strip_edges()
		var context := String(entry.get(_catalog.KEY_CONTEXT, "")).strip_edges()
		var section := String(entry.get(_catalog.KEY_SECTION, "")).strip_edges()
		if keys == "" or action == "" or context == "" or section == "":
			push_error("a shortcut row is missing a column")
			return 1
		var identity := "%s|%s" % [keys, context]
		if seen.has(identity):
			push_error("duplicate shortcut row: %s" % identity)
			return 1
		seen[identity] = true
		if sections.is_empty() or sections[sections.size() - 1] != section:
			if section in sections:
				push_error("section %s is split across the table" % section)
				return 1
			sections.append(section)
		if keys == "K":
			has_open = true
		if keys == "Ctrl/Cmd + S":
			has_search = true
		if keys == "Ctrl/Cmd + Z":
			has_undo = true
		if keys == "T":
			has_views = true
	if not has_open or not has_search or not has_undo or not has_views:
		push_error("the table is missing K, search, undo, or the top view")
		return 1
	if sections != ["App", "Selection", "Camera"]:
		push_error("shortcut sections are out of order: %s" % str(sections))
		return 1
	return 0


func _test_window_placement() -> int:
	var desktop := Vector2(1440, 900)
	var size: Vector2 = _window.opening_window_size(desktop)
	if size.x > desktop.x or size.y > desktop.y:
		push_error("the shortcuts window is larger than the desktop")
		return 1
	if size.x < 640.0 or size.y < 360.0:
		push_error("the shortcuts window is smaller than its minimum on a desktop")
		return 1
	var tiny := Vector2(400, 300)
	var tiny_size: Vector2 = _window.opening_window_size(tiny)
	if tiny_size.x > tiny.x or tiny_size.y > tiny.y:
		push_error("the shortcuts window does not fit a small viewport")
		return 1
	var top_left: Vector2 = _window.centered_top_left(desktop, size)
	if top_left.x < 0.0 or top_left.y < 0.0:
		push_error("the shortcuts window opens off screen")
		return 1
	if top_left.x + size.x > desktop.x or top_left.y + size.y > desktop.y:
		push_error("the shortcuts window extends past the desktop")
		return 1
	return 0


func _test_resize() -> int:
	var viewport := Vector2(1440, 900)
	var start: Vector2 = _window.opening_window_size(viewport)
	var grown: Vector2 = _window.resized_window_size(start, Vector2(180, 90), "corner", viewport)
	if grown.x <= start.x or grown.y <= start.y:
		push_error("a corner drag should grow the shortcuts window")
		return 1
	var wider: Vector2 = _window.resized_window_size(start, Vector2(40, 80), "right", viewport)
	if wider.x <= start.x or wider.y != start.y:
		push_error("the right edge should change width only")
		return 1
	var taller: Vector2 = _window.resized_window_size(start, Vector2(40, 80), "bottom", viewport)
	if taller.y <= start.y or taller.x != start.x:
		push_error("the bottom edge should change height only")
		return 1
	var shrunk: Vector2 = _window.resized_window_size(start, Vector2(-2000, -2000), "corner", viewport)
	if shrunk.x != _window.MIN_WINDOW_SIZE.x or shrunk.y != _window.MIN_WINDOW_SIZE.y:
		push_error("a shrink should stop at the minimum size, got %s" % shrunk)
		return 1
	var capped: Vector2 = _window.resized_window_size(start, Vector2(5000, 5000), "corner", viewport)
	if capped.x > viewport.x or capped.y > viewport.y:
		push_error("a drag should stay inside the viewport")
		return 1
	return 0
