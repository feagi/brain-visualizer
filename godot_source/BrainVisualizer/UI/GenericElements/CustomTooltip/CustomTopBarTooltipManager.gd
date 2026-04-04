extends Node
class_name CustomTopBarTooltipManager

## Above [FloatingWindowsLayer] (layer 1) in BrainVisualizer.tscn so styled tooltips are never buried.
const TOOLTIP_CANVAS_LAYER: int = 100
## [UITabContainer] must use a **higher** layer than [TopBar]'s manager: TopBar is listed after [CB_Holder]
## under [UIManager], so same layer (100) would paint tab tooltips under the global top bar.
var tooltip_canvas_layer: int = TOOLTIP_CANVAS_LAYER
## When true, [CanvasLayer] is moved under [member BV.UI] so tooltip coords match anchors anywhere in the tree
## (dropdown rows reparented to root, [CB_Holder] tab strip, etc.). Required for correct anchoring.
var reparent_tooltip_canvas_to_uIManager: bool = true

const PREFAB_TOOLTIP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTopBarTooltip.tscn")
const PREFAB_SIDE_TOOLTIP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomSideCaretTooltip.tscn")
const CUSTOM_TOOLTIP_TRIGGER_SCRIPT = preload("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTooltipTrigger.gd")

var _tooltip: CustomTopBarTooltip
var _tooltip_side: CustomSideCaretTooltip
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
	_tooltip_layer.layer = tooltip_canvas_layer
	_tooltip_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tooltip_layer)
	
	_tooltip_container = Control.new()
	_tooltip_container.name = "CustomTooltipContainer"
	_tooltip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_layer.add_child(_tooltip_container)
	
	_tooltip = PREFAB_TOOLTIP.instantiate()
	_tooltip_container.add_child(_tooltip)
	
	_tooltip_side = PREFAB_SIDE_TOOLTIP.instantiate()
	_tooltip_container.add_child(_tooltip_side)
	
	_virtual_tab_anchor = Control.new()
	_virtual_tab_anchor.name = "VirtualTabAnchor"
	_virtual_tab_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_container.add_child(_virtual_tab_anchor)
	# Always defer: during TopBar/_ready(), BV.UI may still be "busy setting up children";
	# synchronous add_child to BV.UI triggers scene/main/node blocked > 0.
	if reparent_tooltip_canvas_to_uIManager:
		call_deferred("_reparent_tooltip_canvas_to_uIManager")


func _reparent_tooltip_canvas_to_uIManager() -> void:
	if not reparent_tooltip_canvas_to_uIManager:
		return
	if _tooltip_layer == null or not is_instance_valid(_tooltip_layer):
		return
	if not is_instance_valid(BV) or BV.UI == null:
		return
	var ui_root: Node = BV.UI as Node
	if _tooltip_layer.get_parent() == ui_root:
		return
	var par: Node = _tooltip_layer.get_parent()
	if par != null:
		par.remove_child(_tooltip_layer)
	ui_root.add_child(_tooltip_layer)
	_tooltip_layer.name = "StyledTooltipCanvasLayer"
	var top_bar: Node = ui_root.get_node_or_null("TopBar")
	if top_bar != null:
		ui_root.move_child(_tooltip_layer, top_bar.get_index() + 1)
	else:
		ui_root.move_child(_tooltip_layer, 0)


## Maps [param anchor] bounds to root [Window] coordinates (same space as [method FilterableListPopup._get_anchor_screen_position]).
## For the root viewport, [method Control.get_global_rect] can disagree with reparented [PopupPanel] row controls (tooltips clamped to the left).
## SubViewport-embedded anchors keep using scaled [method Control.get_global_rect] mapping.
static func anchor_control_global_rect_window(anchor: Control) -> Rect2:
	if anchor == null or not is_instance_valid(anchor):
		return Rect2()
	var vp: Viewport = anchor.get_viewport()
	if vp == null:
		return anchor.get_global_rect()
	if vp is SubViewport:
		var sub: SubViewport = vp as SubViewport
		var parent: Node = sub.get_parent()
		if parent != null and parent is SubViewportContainer:
			var svc: SubViewportContainer = parent as SubViewportContainer
			var r: Rect2 = anchor.get_global_rect()
			var cr: Rect2 = svc.get_global_rect()
			var vp_size: Vector2 = Vector2(sub.size)
			if vp_size.x > 0.0 and vp_size.y > 0.0:
				var scale: Vector2 = svc.size / vp_size
				return Rect2(cr.position + r.position * scale, r.size * scale)
		return anchor.get_global_rect()
	var top_left: Vector2 = anchor.get_global_position()
	var sz: Vector2 = anchor.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = anchor.get_global_rect().size
	return Rect2(top_left, sz)


## Replaces native tooltips on [ToggleImageDropDown] popup row [TextureButton]s with [CustomTooltipTrigger].
## Call this **before** [method strip_native_tooltips_recursive] on the same subtree so scene tooltip strings are preserved.
## [param use_side_caret_for_menu_items]: inspector-style rows use [CustomSideCaretTooltip] (caret left, text right).
static func wire_toggle_dropdown_menu_tooltips(
	toggle: ToggleImageDropDown,
	use_side_caret_for_menu_items: bool = false
) -> void:
	if toggle == null or not is_instance_valid(toggle):
		return
	var holder: Node = toggle.get_node_or_null("PanelContainer/BoxContainer")
	if holder == null:
		return
	for child in holder.get_children():
		if not (child is TextureButton):
			continue
		var ctl: Control = child as Control
		var txt: String = ctl.tooltip_text
		ctl.tooltip_text = ""
		if txt.is_empty():
			continue
		if ctl.get_node_or_null("TooltipTrigger") != null:
			continue
		var trigger := Node.new()
		trigger.set_script(CUSTOM_TOOLTIP_TRIGGER_SCRIPT)
		trigger.name = "TooltipTrigger"
		ctl.add_child(trigger)
		trigger.set("tooltip_text", txt)
		trigger.set("use_side_caret_tooltip", use_side_caret_for_menu_items)


## Remove Godot built-in tooltips from a control and every descendant (composite dropdowns, etc.).
static func strip_native_tooltips_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).tooltip_text = ""
	for child in node.get_children():
		strip_native_tooltips_recursive(child)

func show_tooltip(text: String, anchor_control: Control) -> void:
	if _tooltip_side and is_instance_valid(_tooltip_side):
		_tooltip_side.hide_tooltip()
	if _tooltip and is_instance_valid(_tooltip):
		if anchor_control and is_instance_valid(anchor_control):
			_tooltip.show_tooltip(text, anchor_control)


func show_tooltip_side_caret(text: String, anchor_control: Control) -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.hide_tooltip()
	if _tooltip_side and is_instance_valid(_tooltip_side):
		if anchor_control and is_instance_valid(anchor_control):
			_tooltip_side.show_tooltip(text, anchor_control)


func show_tooltip_at_tab(text: String, tab_bar: Control, tab_index: int) -> void:
	if _tooltip_side and is_instance_valid(_tooltip_side):
		_tooltip_side.hide_tooltip()
	if not _tooltip or not is_instance_valid(_tooltip):
		return
	
	if not tab_bar or not is_instance_valid(tab_bar):
		return
	
	if not tab_bar.has_method("get_tab_rect"):
		show_tooltip(text, tab_bar)
		return
	
	var tab_rect: Rect2 = tab_bar.get_tab_rect(tab_index)
	# Map tab-local rect to root space (TabBar has no to_global in some builds; use CanvasItem transform).
	var xf: Transform2D = tab_bar.get_global_transform()
	var top_left: Vector2 = xf * tab_rect.position
	var bottom_right: Vector2 = xf * (tab_rect.position + tab_rect.size)
	var global_tab_rect := Rect2(top_left, bottom_right - top_left)
	
	if not _virtual_tab_anchor or not is_instance_valid(_virtual_tab_anchor):
		return
	
	_virtual_tab_anchor.global_position = global_tab_rect.position
	_virtual_tab_anchor.size = global_tab_rect.size
	
	_tooltip.show_tooltip(text, _virtual_tab_anchor)

func hide_tooltip() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.hide_tooltip()
	if _tooltip_side and is_instance_valid(_tooltip_side):
		_tooltip_side.hide_tooltip()

func get_custom_tooltip_manager() -> Node:
	return self

func _exit_tree() -> void:
	if _tooltip_layer != null and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
