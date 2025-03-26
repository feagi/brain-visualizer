extends Node
class_name UIManager
## Manages UI aspects of BV as a whole

const PREFAB_CB: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.tscn")

# TODO dev menu - build_settings_object



## public var references and init for this object
#region References and Init

var window_manager: WindowManager:
	get: return _window_manager
var notification_system: NotificationSystem:
	get: return _notification_system
var top_bar: TopBar:
	get: return _top_bar
var root_UI_view: UIView:
	get: return _root_UI_view
var selection_system: SelectionSystem:
	get: return _selection_system
	
var temp_root_bm: UI_BrainMonitor_3DScene

var _top_bar: TopBar
var _window_manager: WindowManager
var _root_UI_view: UIView
var _notification_system: NotificationSystem
var _version_label: Label
var _selection_system: SelectionSystem
var _temp_bm_holder: UI_Capsules_Capsule


func _enter_tree():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)
	_find_possible_scales()
	_load_new_theme(load("res://BrainVisualizer/UI/Themes/1-DARK.tres")) #TODO temporary!

func _ready():
	_notification_system = $NotificationSystem
	_top_bar = $TopBar
	_window_manager = $WindowManager
	_version_label = $VersionLabel
	_root_UI_view = $CB_Holder/UIView
	_selection_system = SelectionSystem.new()
	
	_version_label.text = Time.get_datetime_string_from_unix_time(BVVersion.brain_visualizer_timestamp)
	_top_bar.resized.connect(_top_bar_resized)
	_top_bar_resized()
	
	#TODO updated is commented out due to these signals being called when we merely retrieve the data but dont update anything, causing it to be spammed. We may wish to address this
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_added.connect(_proxy_notification_cortical_area_added)
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_about_to_be_removed.connect(_proxy_notification_cortical_area_removed)
	#FeagiCore.feagi_local_cache.cortical_areas.cortical_area_mass_updated.connect(_proxy_notification_cortical_area_updated)
	#FeagiCore.feagi_local_cache.cortical_areas.cortical_area_mappings_changed.connect(_proxy_notification_mappings_updated)
	FeagiCore.feagi_local_cache.morphologies.morphology_added.connect(_proxy_notification_morphology_added)
	FeagiCore.feagi_local_cache.morphologies.morphology_about_to_be_removed.connect(_proxy_notification_morphology_removed)
	#FeagiCore.feagi_local_cache.morphologies.morphology_updated.connect(_proxy_notification_morphology_updated)
	FeagiCore.feagi_local_cache.brain_readiness_changed.connect(func(ready: bool): toggle_loading_screen(!ready))
	BV.UI.selection_system.objects_selection_event_called.connect(_selection_processing)

	

#endregion


## Interactions with FEAGICORE
#region FEAGI Interactions
## Called from above when we are about to reset genome, may want to clear some things...
func FEAGI_about_to_reset_genome() -> void:
	_notification_system.add_notification("Reloading Genome...", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
	_window_manager.force_close_all_windows()
	#_root_UI_view.close_all_non_root_brain_region_views()
	#toggle_loading_screen(true)
	if _temp_bm_holder:
		(_temp_bm_holder.get_holding_UI() as UI_BrainMonitor_3DScene).clear_all_open_previews()
		_temp_bm_holder.queue_free()
	


## Called from above when we have no genome, disable UI elements that connect to it
func FEAGI_no_genome() -> void:
	print("UI: Disabling FEAGI UI elements due to no genome")
	window_manager.force_close_all_windows()
	top_bar.toggle_buttons_interactability(false)


## Called from above when we confirmed genome to feagi, enable UI elements that connect to it
func FEAGI_confirmed_genome() -> void:
	print("UI: Enabling FEAGI UI elements now that genome is confirmed")
	top_bar.toggle_buttons_interactability(true)
	if !FeagiCore.feagi_local_cache.brain_regions.is_root_available():
		push_error("UI: Unable to init root region for CB and BM since no root region was detected!")
		return
	
	var initial_tabs: Array[Control]
	#TODO need a better function to add CB in general
	var cb: CircuitBuilder = PREFAB_CB.instantiate()
	cb.setup(FeagiCore.feagi_local_cache.brain_regions.get_root_region())
	
	initial_tabs = [cb]
	_root_UI_view.reset()
	_root_UI_view.set_this_as_root_view()
	_root_UI_view.setup_as_single_tab(initial_tabs)
	toggle_loading_screen(false)
	
	# temp BM
	_temp_bm_holder = UI_Capsules_Capsule.spawn_uninitialized_UI_in_capsule(UI_Capsules_Capsule.HELD_TYPE.BRAIN_MONITOR)
	$test.add_child(_temp_bm_holder)
	var brain_monitor: UI_BrainMonitor_3DScene = _temp_bm_holder.get_holding_UI() as UI_BrainMonitor_3DScene
	brain_monitor.setup(FeagiCore.feagi_local_cache.brain_regions.get_root_region())
	brain_monitor.requesting_to_fire_selected_neurons.connect(_send_activations_to_FEAGI)
	temp_root_bm = brain_monitor
	
	# This is utter cancer
	set_advanced_mode(FeagiCore._in_use_endpoint_details.is_advanced_mode)
	var option_string: String = FeagiCore._in_use_endpoint_details.theme_string
	if option_string == "":
		return
	var split_strings: PackedStringArray = option_string.split(" ")
	var color_setting: UIManager.THEME_COLORS
	if split_strings[0] == "Dark":
		color_setting = UIManager.THEME_COLORS.DARK
	var zoom_value: float = split_strings[1].to_float()
	BV.UI.request_switch_to_theme(zoom_value, color_setting)
	
# TEMP - > for sending activation firings to FEAGI
func _send_activations_to_FEAGI(area_IDs_and_neuron_coordinates: Dictionary[StringName, Array]) -> void:
	var dict_to_send: Dictionary = {'data': {'direct_stimulation' : {}}}
	for area_ID in area_IDs_and_neuron_coordinates:
		var arr: Array[Array] = []
		for vector in area_IDs_and_neuron_coordinates[area_ID]:
			arr.append([vector.x, vector.y, vector.z])
		dict_to_send["data"]["direct_stimulation"][area_ID] = arr
	
	FeagiCore.network.websocket_API.websocket_send(JSON.stringify(dict_to_send))



#endregion


#region User Interactions
signal advanced_mode_setting_changed(is_in_advanced_mode: bool)


var is_in_advanced_mode: bool:
	get: return _is_in_advanced_mode

func _input(event):
	if FeagiCore.feagi_settings == null:
		return
	
	if event is InputEventKey:
		var keyboard_event: InputEventKey = event as InputEventKey
		if keyboard_event.keycode == FeagiCore.feagi_settings.developer_menu_hotkey:
			if !keyboard_event.pressed:
				return
			if !FeagiCore.feagi_settings.allow_developer_menu:
				return
			show_developer_menu()

var _is_in_advanced_mode: bool = false

func set_advanced_mode(is_advanced_mode: bool) -> void:
	if is_advanced_mode == _is_in_advanced_mode:
		return
	_is_in_advanced_mode = is_advanced_mode
	advanced_mode_setting_changed.emit(_is_in_advanced_mode)


## Open the developer menu
func show_developer_menu():
	_window_manager.spawn_developer_options()



func toggle_loading_screen(is_on: bool) -> void:
	$TempLoadingScreen.visible = is_on

func _selection_processing(objects: Array[GenomeObject], context: SelectionSystem.SOURCE_CONTEXT, override_usecases: Array[SelectionSystem.OVERRIDE_USECASE]) -> void:
	if !(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT in override_usecases):
		_window_manager.spawn_quick_cortical_menu(objects)
	if SelectionSystem.OVERRIDE_USECASE.CORTICAL_PROPERTIES in override_usecases:
		var cortical_areas: Array[AbstractCorticalArea] = GenomeObject.filter_cortical_areas(objects)
		if len(cortical_areas) != 0:
			_window_manager.spawn_adv_cortical_properties(cortical_areas)

#endregion


## Functionality related to screen size, theming, and scaling of all elements
#region Theming and Scaling
const THEME_FOLDER: StringName = "res://BrainVisualizer/UI/Themes/"

enum THEME_COLORS { # SO MANY COLORS
	DARK
}

signal screen_size_changed(new_screen_size: Vector2)
signal theme_changed(theme: Theme) ## New theme (likely with vustom scale changes) applied

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size
var screen_center: Vector2:
	get: return _screen_size / 2.0
var loaded_theme: Theme:
	get: return _loaded_theme
var possible_UI_scales: Array[float]:
	get: return _possible_UI_scales
var loaded_theme_scale: Vector2:
	get: return _loaded_theme_scale

var _screen_size: Vector2
var _loaded_theme: Theme
var _loaded_theme_scale: Vector2 = Vector2(1.0, 1.0)
var _possible_UI_scales: Array[float] = []


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


## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)
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

#endregion


## To prevent spam, some signals are first validated to ensure they aren't being spammed
#region Notification Filtering Proxies

## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_cortical_area_added(cortical_area: AbstractCorticalArea) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed addition of cortical area %s!" % cortical_area.friendly_name)
	
	
## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_cortical_area_updated(cortical_area: AbstractCorticalArea) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed update of cortical area %s!" % cortical_area.friendly_name)
	
	
## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_cortical_area_removed(cortical_area: AbstractCorticalArea) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed removal of cortical area %s!" % cortical_area.friendly_name)
	
## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_mappings_updated(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed updated mapping information from %s to %s!" % [source.friendly_name, destination.friendly_name])


## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_morphology_added(morphology: BaseMorphology) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed addition of connectivity rule %s!" % morphology.name)


## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_morphology_updated(morphology: BaseMorphology) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed update of connectivity rule %s!" % morphology.name)


## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_morphology_removed(morphology: BaseMorphology) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed removal of connectivity rule %s!" % morphology.name)

#endregion

#region Icons for cortical areas

const ICON_CUSTOM_INPUT: StringName = "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/unknowns/custom-input.png"
const ICON_CUSTOM_OUTPUT: StringName = "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/unknowns/custom-output.png"

const KNOWN_ICON_PATHS : Dictionary = {
	"ishock" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/ishock.png",
	"iv00_C" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/iv00_C.png",
	"i_hear" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i_hear.png",
	"i_spos" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i_spos.png",
	"i__acc" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__acc.png",
	"i__bat" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__bat.png",
	"i__bci" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__bci.png",
	"i__gyr" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__gyr.png",
	"i__inf" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__inf.png",
	"i__pro" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__pro.png",
	"i___id" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i___id.png",
	"o__mot" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/o__mot.png",
	"___pwr" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/___pwr.png",
}

## Gets the icon texture given the cortical ID
static func get_icon_texture_by_ID(cortical_ID: StringName, fallback_is_input: bool = true) -> Texture:
	if cortical_ID in KNOWN_ICON_PATHS:
		return (load(KNOWN_ICON_PATHS[cortical_ID]) as Texture)
	if fallback_is_input:
		return  (load(ICON_CUSTOM_INPUT) as Texture)
	else:
		return  (load(ICON_CUSTOM_OUTPUT) as Texture)
	
	




#endregion
