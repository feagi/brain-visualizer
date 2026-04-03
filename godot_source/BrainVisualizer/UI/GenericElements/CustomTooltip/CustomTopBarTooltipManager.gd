extends Node
class_name CustomTopBarTooltipManager

## Above [FloatingWindowsLayer] (layer 1) in BrainVisualizer.tscn so styled tooltips are never buried.
const TOOLTIP_CANVAS_LAYER: int = 100

const PREFAB_TOOLTIP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTopBarTooltip.tscn")

var _tooltip: CustomTopBarTooltip
var _tooltip_layer: CanvasLayer
var _tooltip_container: Control
var _virtual_tab_anchor: Control

func _ready():
	_setup_tooltip()

func _setup_tooltip() -> void:
	# Parent layer under this manager (hosted under TopBar or UITabContainer) so coordinates match
	# the same viewport / embedding as the bars — avoid attaching to root only.
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "CustomTopBarTooltipLayer"
	_tooltip_layer.layer = TOOLTIP_CANVAS_LAYER
	_tooltip_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tooltip_layer)
	
	_tooltip_container = Control.new()
	_tooltip_container.name = "CustomTooltipContainer"
	_tooltip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_layer.add_child(_tooltip_container)
	
	_tooltip = PREFAB_TOOLTIP.instantiate()
	_tooltip_container.add_child(_tooltip)
	
	_virtual_tab_anchor = Control.new()
	_virtual_tab_anchor.name = "VirtualTabAnchor"
	_virtual_tab_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_container.add_child(_virtual_tab_anchor)

## Remove Godot built-in tooltips from a control and every descendant (composite dropdowns, etc.).
static func strip_native_tooltips_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).tooltip_text = ""
	for child in node.get_children():
		strip_native_tooltips_recursive(child)

func show_tooltip(text: String, anchor_control: Control) -> void:
	if _tooltip and is_instance_valid(_tooltip):
		if anchor_control and is_instance_valid(anchor_control):
			_tooltip.show_tooltip(text, anchor_control)

func show_tooltip_at_tab(text: String, tab_bar: Control, tab_index: int) -> void:
	if not _tooltip or not is_instance_valid(_tooltip):
		return
	
	if not tab_bar or not is_instance_valid(tab_bar):
		return
	
	if not tab_bar.has_method("get_tab_rect"):
		show_tooltip(text, tab_bar)
		return
	
	var tab_rect: Rect2 = tab_bar.get_tab_rect(tab_index)
	var global_pos = tab_bar.global_position + tab_rect.position
	
	if not _virtual_tab_anchor or not is_instance_valid(_virtual_tab_anchor):
		return
	
	_virtual_tab_anchor.global_position = global_pos
	_virtual_tab_anchor.size = tab_rect.size
	
	_tooltip.show_tooltip(text, _virtual_tab_anchor)

func hide_tooltip() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.hide_tooltip()

func get_custom_tooltip_manager() -> Node:
	return self

func _exit_tree() -> void:
	if _tooltip_layer != null and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
