extends Node
class_name UIManager

# TODO dev menu - build_settings_object

const THEME_FOLDER: StringName = "res://BrainVisualizer/UI/Themes/"

enum THEME_COLORS { # SO MANY COLORS
	DARK
}

signal screen_size_changed(new_screen_size: Vector2)
signal theme_changed(theme: Theme) ## New theme (likely with vustom scale changes) applied
signal toggle_keyboard_controls(enable_controls: bool) ## True if keyboard controls (such as for camera) should be enabled. False in cases such as user typing #TODO is needed?
signal user_selected_single_cortical_area(area: BaseCorticalArea) ## User selected a single cortical area specifically (IE doesn't fire when a user drag selects multiple)

var window_manager: WindowManager:
	get: return _window_manager
var circuit_builder: CorticalNodeGraph:
	get: return _circuit_builder
var notification_system: NotificationSystem:
	get: return _notification_system
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
var possible_UI_scales: Array[float]:
	get: return _possible_UI_scales
var loaded_theme_scale: Vector2:
	get: return _loaded_theme_scale

var _screen_size: Vector2
var _selected_cortical_areas: Array[BaseCorticalArea] = []
var _loaded_theme: Theme
var _loaded_theme_scale: Vector2 = Vector2(1.0, 1.0)
var _top_bar: TopBar
var _possible_UI_scales: Array[float] = []
var _circuit_builder: CorticalNodeGraph
var _brain_monitor # lol
var _window_manager: WindowManager
var _notification_system: NotificationSystem
var _version_label: Label


func _enter_tree():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)
	_find_possible_scales()
	_load_new_theme(load("res://BrainVisualizer/UI/Themes/1-DARK.tres")) #TODO temporary!

func _ready():
	_notification_system = $NotificationSystem
	_top_bar = $TopBar
	_circuit_builder = $CB_Holder/CircuitBuilder
	_brain_monitor = $BrainMonitor
	_window_manager = $WindowManager
	_version_label = $VersionLabel
	
	_version_label.text = Time.get_datetime_string_from_unix_time(BVVersion.brain_visualizer_timestamp)
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

## Starts a preview cort a cortical area
func start_cortical_area_preview(initial_position: Vector3, initial_dimensions: Vector3, 
	position_signals: Array[Signal], dimensions_signals: Array[Signal], close_signals: Array[Signal],
 	color: Color = BrainMonitorSinglePreview.DEFAULT_COLOR, is_rendering: bool = true) -> void:
	
	var preview_handler: GenericSinglePreviewHandler = GenericSinglePreviewHandler.new()
	add_child(preview_handler)
	preview_handler.start_BM_preview(initial_dimensions, initial_position, color, is_rendering)
	preview_handler.connect_BM_preview(position_signals, dimensions_signals, close_signals)
	# when moving this to BM, add a signal here to closing all handlers and append that signal to the above close array!

## Given the element node, uses the theme_variant property to retrieve the minimum size of the current theme. If there is no theme variant, fall back onto the given default option
func get_minimum_size_from_loaded_theme_variant_given_control(control: Control, fallback_type: StringName) -> Vector2i:
	if control.theme_type_variation != &"":
		fallback_type = control.theme_type_variation
	return get_minimum_size_from_loaded_theme(fallback_type)

## Given the name of the element, try to grab the minimum size defined by the currently loaded theme. If element doesnt exist, return 32x32
func get_minimum_size_from_loaded_theme(element: StringName) -> Vector2i:
	var output: Vector2i = Vector2i(32,32)
	
	if loaded_theme == null:
		push_error("THEME: Theme has not been loaded correctly, a LOT of UI elements will be broken!")
		return output
	
	if loaded_theme.has_constant("size_x", element):
		output.x = loaded_theme.get_constant("size_x", element)
	else:
		push_error("THEME: Loaded theme file is missing size_x for element %s. There will be sizing issues!" % element)
	if BV.UI.loaded_theme.has_constant("size_y", element):
		output.y = loaded_theme.get_constant("size_y", element)
	else:
		push_error("THEME: Loaded theme file is missing size_y for element %s. There will be sizing issues!" % element)
	return output


## Attempts to switch toa  theme file with the given scale and color. If it doesnt exist, will do nothing
func request_switch_to_theme(requested_scale: float, color: THEME_COLORS) -> void:
	var file_list: PackedStringArray = DirAccess.get_files_at(THEME_FOLDER)
	var guessing_file: StringName = str(requested_scale) + "-" + THEME_COLORS.keys()[color] + ".tres"
	if !(guessing_file in file_list):
		push_error("THEME: Unable to find theme file %s!" % guessing_file)
		return
	var theme_file: Theme = load(THEME_FOLDER + guessing_file)
	if theme_file == null:
		push_error("THEME:  Found theme file %s but unable to parse file as a theme!" % guessing_file)
		return
	print("THEME: Loading theme %s..." % guessing_file)
	_load_new_theme(theme_file)


## Called from above when we are about to reset genome, may want to clear some things...
func FEAGI_about_to_reset_genome() -> void:
	_notification_system.add_notification("Reloading Genome...", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
	_window_manager.force_close_all_windows()


## Called from above when we have no genome, disable UI elements that connect to it
func FEAGI_no_genome() -> void:
	print("UI: Disabling FEAGI UI elements due to no genome")
	window_manager.force_close_all_windows()
	top_bar.toggle_buttons_interactability(false)


## Called from above when we confirmed genome to feagi, enable UI elements that connect to it
func FEAGI_confirmed_genome() -> void:
	print("UI: Enabling FEAGI UI elements now that genome is confirmed")
	top_bar.toggle_buttons_interactability(true)


## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)
	if OS.is_debug_build():
		print("UI: Window Size Change Detected!")

## Used to reposition notifications so they dont intersect with top bar
func _top_bar_resized() -> void:
	_notification_system.position.y = _top_bar.size.y + _top_bar.position.y

func _load_new_theme(theme: Theme) -> void:
	var scalar: Vector2 = Vector2(1,1)
	
	_loaded_theme = theme
	if _loaded_theme.has_constant("size_x", "generic_scale"):
		scalar.x = float(_loaded_theme.get_constant("size_x", "generic_scale")) / 4.0
	else:
		push_error("UI: Unable to find size_x under the generic_scale type of the newely loaded theme! There will be scaling issues!")
	if _loaded_theme.has_constant("size_y", "generic_scale"):
		scalar.y = float(_loaded_theme.get_constant("size_y", "generic_scale")) / 4.0
	else:
		push_error("UI: Unable to find size_y under the generic_scale type of the newely loaded theme! There will be scaling issues!")
	
	_loaded_theme_scale = scalar
	
	$VersionLabel.theme = theme
	theme_changed.emit(theme)


func _find_possible_scales() -> void:
	var file_list: PackedStringArray = DirAccess.get_files_at(THEME_FOLDER)
	for file: StringName in file_list:
		var first_part: StringName = file.get_slice("-", 0)
		if first_part.is_valid_float():
			_possible_UI_scales.append(first_part.to_float())
