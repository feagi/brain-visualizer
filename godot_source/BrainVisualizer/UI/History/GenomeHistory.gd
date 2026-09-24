extends RefCounted
class_name GenomeHistory
## Session undo and redo stacks. A new gesture clears redo. Loading another genome clears both.

const HISTORY_LIMIT: int = 50

var _undo: Array[GenomeEdit] = []
var _redo: Array[GenomeEdit] = []
var _accepting: bool = false


func set_accepting(accepting: bool) -> void:
	_accepting = accepting


func is_accepting() -> bool:
	return _accepting


func record(edit: GenomeEdit) -> void:
	if not _accepting or edit == null or edit.is_empty():
		return
	_undo.append(edit)
	while _undo.size() > HISTORY_LIMIT:
		_undo.pop_front()
	_redo.clear()


func clear() -> void:
	_undo.clear()
	_redo.clear()


func has_undo() -> bool:
	return not _undo.is_empty()


func has_redo() -> bool:
	return not _redo.is_empty()


func undo_count() -> int:
	return _undo.size()


func redo_count() -> int:
	return _redo.size()


func peek_undo() -> GenomeEdit:
	if _undo.is_empty():
		return null
	return _undo[_undo.size() - 1]


func peek_redo() -> GenomeEdit:
	if _redo.is_empty():
		return null
	return _redo[_redo.size() - 1]


func confirm_undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_undo.pop_back())


func confirm_redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_redo.pop_back())


## Ctrl/Cmd+Z undoes. Shift+Ctrl/Cmd+Z redoes. Text fields keep their own undo.
static func history_shortcut(keycode: Key, with_command: bool, shift_pressed: bool, alt_pressed: bool, pressed: bool, echo: bool) -> StringName:
	if keycode != KEY_Z or not with_command or alt_pressed or not pressed or echo:
		return &""
	if shift_pressed:
		return &"redo"
	return &"undo"


static func focus_blocks_history_shortcut(focus_owner: Control) -> bool:
	return focus_owner is LineEdit or focus_owner is TextEdit
