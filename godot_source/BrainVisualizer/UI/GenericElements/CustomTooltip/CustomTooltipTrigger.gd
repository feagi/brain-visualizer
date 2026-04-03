extends Node
class_name CustomTooltipTrigger

@export var tooltip_text: String = ""
@export var tooltip_manager_path: NodePath

var _parent_control: Control
var _tooltip_manager: Node
var _is_hovering: bool = false

func _ready():
	_parent_control = get_parent() as Control
	if _parent_control == null:
		push_error("CustomTooltipTrigger: Parent must be a Control!")
		return
	
	if not tooltip_manager_path.is_empty():
		_tooltip_manager = get_node(tooltip_manager_path)
	else:
		# Do not use a shared group: every UITabContainer also uses CustomTopBarTooltipManager;
		# get_first_node_in_group would often resolve the wrong instance and top-bar hovers show nothing.
		_tooltip_manager = _find_tooltip_manager_in_tree()
	
	if _tooltip_manager == null:
		push_warning("CustomTooltipTrigger: Could not find CustomTopBarTooltipManager for %s!" % _parent_control.name)
		return
	
	_parent_control.mouse_entered.connect(_on_mouse_entered)
	_parent_control.mouse_exited.connect(_on_mouse_exited)
	_parent_control.tree_exiting.connect(_on_parent_tree_exiting)

func _on_mouse_entered() -> void:
	_is_hovering = true
	if not _tooltip_manager or not is_instance_valid(_tooltip_manager):
		return
	if not _parent_control or not is_instance_valid(_parent_control):
		return
	if tooltip_text.is_empty():
		return
	if _tooltip_manager.has_method("show_tooltip"):
		_tooltip_manager.show_tooltip(tooltip_text, _parent_control)

func _on_mouse_exited() -> void:
	_is_hovering = false
	if _tooltip_manager and is_instance_valid(_tooltip_manager) and _tooltip_manager.has_method("hide_tooltip"):
		_tooltip_manager.hide_tooltip()

func _on_parent_tree_exiting() -> void:
	if _is_hovering and _tooltip_manager and is_instance_valid(_tooltip_manager) and _tooltip_manager.has_method("hide_tooltip"):
		_tooltip_manager.hide_tooltip()

func set_tooltip_text(text: String) -> void:
	tooltip_text = text
	if not _is_hovering:
		return
	if not _tooltip_manager or not is_instance_valid(_tooltip_manager):
		return
	if not _parent_control or not is_instance_valid(_parent_control):
		return
	if _tooltip_manager.has_method("show_tooltip"):
		_tooltip_manager.show_tooltip(tooltip_text, _parent_control)

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
