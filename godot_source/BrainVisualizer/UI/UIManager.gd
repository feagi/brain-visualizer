extends Node
class_name UIManager

# TODO dev menu - build_settings_object

signal screen_size_changed(new_screen_size: Vector2)
signal theme_changed(theme: Theme)
signal toggle_keyboard_controls(enable_controls: bool) ## True if keyboard controls (such as for camera) should be enabled. False in cases such as user typing #TODO is needed?
signal user_selected_single_cortical_area(area: BaseCorticalArea) ## User selected a single cortical area specifically (IE doesn't fire when a user drag selects multiple)

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size
var screen_center: Vector2:
	get: return _screen_size / 2.0
var selected_cortical_areas: Array[BaseCorticalArea]:
	get: return _selected_cortical_areas
var loaded_theme: Theme:
	get: return _loaded_theme
var top_bar: TopBar:
	get: return _top_bar
var notification_system: NotificationSystem:
	get: return _notification_system

var _screen_size: Vector2
var _selected_cortical_areas: Array[BaseCorticalArea] = []
var _loaded_theme: Theme
var _top_bar: TopBar
var _circuit_builder: CorticalNodeGraph
var _brain_monitor # lol
var _window_manager: WindowManager
var _notification_system: NotificationSystem

func _enter_tree():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)
	load_new_theme(load("res://BrainVisualizer/UI/Themes/1.0-dark.tres")) #TODO temporary!

func _ready():
	_notification_system = $NotificationSystem
	_top_bar = $TopBar
	_circuit_builder = $CB_Holder/CircuitBuilder
	_brain_monitor = $BrainMonitor
	_window_manager = $WindowManager
	
	_top_bar.resized.connect(_top_bar_resized)
	_top_bar_resized()

func set_user_selected_cortical_areas(selected: Array[BaseCorticalArea]) -> void:
	pass

func user_selected_single_cortical_area_independently(area: BaseCorticalArea) -> void:
	user_selected_single_cortical_area.emit(area)
	_window_manager.spawn_quick_cortical_menu(area)

func user_selected_single_cortical_area_appending(area: BaseCorticalArea) -> void:
	pass

func snap_camera_to_cortical_area(cortical_area: BaseCorticalArea) -> void:
	#TODO change behavior depending on BV / CB
	$Brain_Visualizer.snap_camera_to_cortical_area(cortical_area)

func load_new_theme(theme: Theme) -> void:
	_loaded_theme = theme
	theme_changed.emit(theme)

## Starts a preview cort a cortical area
func start_cortical_area_preview(initial_position: Vector3, initial_dimensions: Vector3, 
	position_signals: Array[Signal], dimensions_signals: Array[Signal], close_signals: Array[Signal],
 	color: Color = BrainMonitorSinglePreview.DEFAULT_COLOR, is_rendering: bool = true) -> void:
	
	var preview_handler: GenericSinglePreviewHandler = GenericSinglePreviewHandler.new()
	add_child(preview_handler)
	preview_handler.start_BM_preview(initial_dimensions, initial_position, color, is_rendering)
	preview_handler.connect_BM_preview(position_signals, dimensions_signals, close_signals)
	# when moving this to BM, add a signal here to closing all handlers and append that signal to the above close array!
	

## Called from above when we are about to reset genome, may want to clear some things...
func FEAGI_about_to_reset_genome() -> void:
	_notification_system.add_notification("Reloading Genome...", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
	_window_manager.force_close_all_windows()

## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)
	if OS.is_debug_build():
		print("UI: Window Size Change Detected!")

## Used to reposition notifications so they dont intersect with top bar
func _top_bar_resized() -> void:
	_notification_system.position.y = _top_bar.size.y + _top_bar.position.y
