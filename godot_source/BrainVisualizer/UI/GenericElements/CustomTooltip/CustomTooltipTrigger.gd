extends Node
class_name CustomTooltipTrigger

## Wait time after hover before showing the styled tooltip (matches default OS tooltip feel).
const SHOW_DELAY_SEC: float = 0.45

@export var tooltip_text: String = ""
## When true, uses [method CustomTopBarTooltipManager.show_tooltip_side_caret] (left caret, body to the right).
@export var use_side_caret_tooltip: bool = false
## 0 keeps [member CustomSideCaretTooltip] defaults. Region descriptions set a larger wrap/line budget.
@export var max_visible_lines: int = 0
@export var max_wrap_width_px: float = 0.0
## Downward tooltips. False keeps the shared two-line cap. True shows the full string.
@export var show_full_text: bool = false
@export var tooltip_manager_path: NodePath

var _parent_control: Control
var _tooltip_manager: Node
var _is_hovering: bool = false
var _show_timer: Timer

func _ready() -> void:
	_parent_control = get_parent() as Control
	if _parent_control == null:
		push_error("CustomTooltipTrigger: Parent must be a Control!")
		return
	
	if not tooltip_manager_path.is_empty():
		_tooltip_manager = get_node(tooltip_manager_path)
	else:
		_tooltip_manager = _find_tooltip_manager_in_tree()
	
	if _tooltip_manager == null:
		push_warning("CustomTooltipTrigger: Could not find CustomTopBarTooltipManager for %s!" % _parent_control.name)
		return
	
	_show_timer = Timer.new()
	_show_timer.name = "ShowDelayTimer"
	_show_timer.one_shot = true
	_show_timer.wait_time = SHOW_DELAY_SEC
	add_child(_show_timer)
	_show_timer.timeout.connect(_on_show_delay_timeout)
	
	_parent_control.mouse_entered.connect(_on_mouse_entered)
	_parent_control.mouse_exited.connect(_on_mouse_exited)
	_parent_control.tree_exiting.connect(_on_parent_tree_exiting)

func _suppress_tooltip_while_dropdown_open() -> bool:
	if _parent_control == null or not is_instance_valid(_parent_control):
		return false
	if _parent_control is ToggleImageDropDown:
		return (_parent_control as ToggleImageDropDown).is_menu_open()
	if _parent_control is ActivityVisualizationDropDown:
		return (_parent_control as ActivityVisualizationDropDown).is_inspector_dropdown_menu_open()
	if _parent_control is ArrangeDropDown:
		return (_parent_control as ArrangeDropDown).is_menu_open()
	return false


func _on_mouse_entered() -> void:
	_is_hovering = true
	if not _tooltip_manager or not is_instance_valid(_tooltip_manager):
		return
	if not _parent_control or not is_instance_valid(_parent_control):
		return
	if tooltip_text.is_empty():
		return
	if _suppress_tooltip_while_dropdown_open():
		return
	if _show_timer:
		_show_timer.start()

func _on_show_delay_timeout() -> void:
	if not _is_hovering:
		return
	if not _tooltip_manager or not is_instance_valid(_tooltip_manager):
		return
	if not _parent_control or not is_instance_valid(_parent_control):
		return
	if tooltip_text.is_empty():
		return
	if _suppress_tooltip_while_dropdown_open():
		return
	if use_side_caret_tooltip and _tooltip_manager.has_method("show_tooltip_side_caret"):
		_tooltip_manager.show_tooltip_side_caret(tooltip_text, _parent_control, max_visible_lines, max_wrap_width_px)
	elif _tooltip_manager.has_method("show_tooltip"):
		var line_cap: int = 0 if show_full_text else -1
		_tooltip_manager.show_tooltip(tooltip_text, _parent_control, line_cap)

func _on_mouse_exited() -> void:
	_is_hovering = false
	if _show_timer:
		_show_timer.stop()
	if _tooltip_manager and is_instance_valid(_tooltip_manager) and _tooltip_manager.has_method("hide_tooltip"):
		_tooltip_manager.hide_tooltip()

func _on_parent_tree_exiting() -> void:
	if _show_timer:
		_show_timer.stop()
	if _is_hovering and _tooltip_manager and is_instance_valid(_tooltip_manager) and _tooltip_manager.has_method("hide_tooltip"):
		_tooltip_manager.hide_tooltip()

func set_tooltip_text(text: String) -> void:
	tooltip_text = text
	if not _is_hovering:
		return
	if _show_timer:
		_show_timer.start()

func _find_tooltip_manager_in_tree() -> Node:
	var current = get_parent()
	while current != null:
		if current.has_method("get_custom_tooltip_manager"):
			return current.get_custom_tooltip_manager()
		for child in current.get_children():
			if child.get_script() and child.get_script().get_global_name() == "CustomTopBarTooltipManager":
				return child
		current = current.get_parent()
	return null
