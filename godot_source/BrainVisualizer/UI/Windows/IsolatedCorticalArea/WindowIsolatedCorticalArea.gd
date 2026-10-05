extends BaseDraggableWindow
class_name WindowIsolatedCorticalArea
## Floating 3D inspect view of one cortical area. Opens with its top-left on the click.
## Drag the bottom-right corner, right edge, or bottom edge to resize. An outside click closes it.

const WINDOW_NAME: StringName = &"isolated_cortical_inspect"
const IsolatedAreaInspectLib = preload("res://addons/UI_BrainMonitor/IsolatedAreaInspect.gd")

## Size when the view first opens.
@export var view_size: Vector2 = Vector2(480, 360)
## Smallest size the user can drag to.
const MIN_VIEW_SIZE: Vector2 = Vector2(280, 200)
const RESIZE_EDGE: float = 14.0
const BORDER_COLOR: Color = Color(0.72, 0.58, 0.28, 0.95)
const BORDER_WIDTH: int = 2

var _click_point: Vector2 = Vector2.ZERO
var _has_click_point: bool = false
var _area: AbstractCorticalArea = null
var _monitor: UI_BrainMonitor_3DScene = null
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	apply_condensed_chrome()
	_apply_visible_border()
	custom_minimum_size = view_size
	_add_resize_handles()


## Click position in root-viewport space. Set before [method setup].
func set_click_point(click_in_root: Vector2) -> void:
	_click_point = click_in_root
	_has_click_point = true


func setup(area: AbstractCorticalArea) -> void:
	if area == null:
		push_error("Isolated cortical inspect was opened without a cortical area")
		close_window()
		return
	_setup_base_window(WINDOW_NAME)
	_area = area
	_titlebar.title = area.friendly_name
	_monitor = UI_BrainMonitor_3DScene.create_uninitialized_brain_monitor()
	_monitor.custom_minimum_size = MIN_VIEW_SIZE
	_monitor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_monitor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_monitor.mouse_filter = Control.MOUSE_FILTER_STOP
	_window_internals.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window_internals.add_child(_monitor)
	_monitor.enable_startup_camera_intro = false
	_monitor.setup_isolated_cortical_area(area)
	_monitor.requesting_to_fire_selected_neurons.connect(BV.UI._send_activations_to_FEAGI)
	_monitor.requesting_to_clear_all_selected_neurons.connect(BV.UI._handle_voxel_selection_cleared)
	_monitor.cortical_area_selected_neurons_changed.connect(BV.UI._handle_voxel_selection_changed)
	_monitor.cortical_area_selected_neurons_changed_delta.connect(BV.UI._handle_voxel_selection_changed_delta)
	if not area.about_to_be_deleted.is_connected(_on_area_deleted):
		area.about_to_be_deleted.connect(_on_area_deleted)
	size = view_size
	_place_when_laid_out()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and _monitor != null and is_instance_valid(_monitor) and _monitor.is_pointer_over_view():
		_monitor.forward_key_to_camera(event)
	if _resizing:
		if event is InputEventMouseMotion:
			_apply_resize()
			accept_event()
			return
		if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
			_resizing = false
			accept_event()
			return
	super._input(event)


func _place_when_laid_out() -> void:
	await get_tree().process_frame
	if _monitor != null and is_instance_valid(_monitor):
		_monitor._update_subviewport_size()
	var window_size: Vector2i = size
	if window_size.x < 2 or window_size.y < 2:
		window_size = Vector2i(view_size)
	if _has_click_point:
		var min_top := 0.0
		if BV != null and BV.WM != null:
			var bar_bottom: int = BV.WM._get_top_bar_bottom_y_in_root_viewport()
			if bar_bottom > 0:
				min_top = float(bar_bottom + WindowManager.ANCHOR_PLACEMENT_MARGIN_PX)
		var pos: Vector2 = IsolatedAreaInspectLib.top_left_for_click(
			_click_point,
			Vector2(window_size),
			get_viewport().get_visible_rect(),
			min_top,
		)
		position = Vector2i(roundi(pos.x), roundi(pos.y))
	visible = true


func _on_area_deleted() -> void:
	close_window()


func _apply_visible_border() -> void:
	if _window_panel == null:
		return
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_color = BORDER_COLOR
	border.set_border_width_all(BORDER_WIDTH)
	_window_panel.add_theme_stylebox_override(&"panel", border)


func _add_resize_handles() -> void:
	var corner := _make_resize_handle("ResizeCorner", Control.CURSOR_FDIAGSIZE, RESIZE_EDGE, RESIZE_EDGE)
	add_child(corner)
	corner.z_index = 100
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.offset_left = -RESIZE_EDGE
	corner.offset_top = -RESIZE_EDGE
	corner.offset_right = 0
	corner.offset_bottom = 0
	corner.draw.connect(_draw_resize_grip.bind(corner))

	var right_edge := _make_resize_handle("ResizeRight", Control.CURSOR_HSIZE, RESIZE_EDGE, 0)
	add_child(right_edge)
	right_edge.z_index = 99
	right_edge.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_edge.offset_left = -RESIZE_EDGE
	right_edge.offset_right = 0
	right_edge.offset_top = 0
	right_edge.offset_bottom = -RESIZE_EDGE

	var bottom_edge := _make_resize_handle("ResizeBottom", Control.CURSOR_VSIZE, 0, RESIZE_EDGE)
	add_child(bottom_edge)
	bottom_edge.z_index = 99
	bottom_edge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_edge.offset_left = 0
	bottom_edge.offset_right = -RESIZE_EDGE
	bottom_edge.offset_top = -RESIZE_EDGE
	bottom_edge.offset_bottom = 0


func _make_resize_handle(handle_name: String, cursor: Control.CursorShape, min_x: float, min_y: float) -> Control:
	var handle := Control.new()
	handle.name = handle_name
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = cursor
	if min_x > 0.0 or min_y > 0.0:
		handle.custom_minimum_size = Vector2(min_x, min_y)
	handle.gui_input.connect(_on_resize_handle_gui_input)
	return handle


func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_resizing = true
		_resize_start_mouse = get_global_mouse_position()
		_resize_start_size = size
		accept_event()
		return
	_resizing = false
	accept_event()


func _apply_resize() -> void:
	var delta := get_global_mouse_position() - _resize_start_mouse
	var new_size: Vector2 = IsolatedAreaInspectLib.resized_size(_resize_start_size, delta, MIN_VIEW_SIZE)
	var room := get_viewport().get_visible_rect().end - Vector2(position)
	new_size.x = minf(new_size.x, maxf(MIN_VIEW_SIZE.x, room.x))
	new_size.y = minf(new_size.y, maxf(MIN_VIEW_SIZE.y, room.y))
	custom_minimum_size = new_size
	size = new_size
	if _monitor != null and is_instance_valid(_monitor):
		_monitor._update_subviewport_size()


func _draw_resize_grip(handle: Control) -> void:
	var color := Color(0.75, 0.78, 0.82, 0.9)
	var inset := 3.0
	handle.draw_line(Vector2(inset, RESIZE_EDGE - inset), Vector2(RESIZE_EDGE - inset, inset), color, 1.5)
	handle.draw_line(Vector2(inset + 4.0, RESIZE_EDGE - inset), Vector2(RESIZE_EDGE - inset, inset + 4.0), color, 1.5)
