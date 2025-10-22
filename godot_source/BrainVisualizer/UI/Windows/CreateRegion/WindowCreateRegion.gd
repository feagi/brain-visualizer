extends BaseDraggableWindow
class_name WindowCreateRegion

const WINDOW_NAME: StringName = "create_region"
const BUTTON_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollIItemPrefab.tscn")


var _region_drop_down: RegionDropDown
var _name_box: TextInput
var _vector: Vector3iSpinboxField
var _add_button: ButtonTextureRectScaling
var _scroll_section: ScrollSectionGeneric
var _preview: UI_BrainMonitor_BrainRegionPreview

func _ready():
	super()
	_region_drop_down = _window_internals.get_node("HBoxContainer3/RegionDropDown")
	_name_box = _window_internals.get_node("HBoxContainer/TextInput")
	_vector = _window_internals.get_node("HBoxContainer2/Vector3fField")
	_add_button = _window_internals.get_node("ScrollSectionGenericTemplate/HBoxContainer/Add")
	_scroll_section = _window_internals.get_node("ScrollSectionGenericTemplate/PanelContainer/ScrollSectionGeneric")


func setup(parent_region: BrainRegion, selected_items: Array[GenomeObject] = []) -> void:
	_setup_base_window(WINDOW_NAME)
	_region_drop_down.set_selected_region(parent_region)
	for selected in selected_items:
		_scroll_section.add_text_button_with_delete(selected, selected.friendly_name, Callable())
	
	# 🎯 FOLLOW CORTICAL AREA PATTERN: Set sensible default coordinates (not 0,0,0)
	# Generate random coordinates in a reasonable range for visibility
	var rand: RandomNumberGenerator = RandomNumberGenerator.new()
	var default_3d = Vector3i(
		rand.randi_range(-50, 50),   # Reasonable X range
		rand.randi_range(5, 25),     # Reasonable Y range (above ground) 
		rand.randi_range(-50, 50)    # Reasonable Z range
	)
	_vector.current_vector = default_3d
	print("🎯 Region creation: Set default 3D coordinates to %s" % default_3d)

	# Clear any existing brain-region previews to avoid duplicates
	_clear_existing_region_previews()
	# Create a lightweight transient region for preview positioning (no mutation of FEAGI cache)
	var temp_region: BrainRegion = BrainRegion.new("__preview__", "(preview)", Vector2i.ZERO, default_3d)
	# Use brain monitor's factory to create the preview (handles parenting/lifecycle)
	var brain_monitor := BV.UI.temp_root_bm
	_preview = brain_monitor.create_brain_region_preview(temp_region, default_3d)

	# React to coordinate spinbox changes to move preview
	_vector.user_updated_vector.connect(_on_preview_coords_changed)
	# Also remove preview once FEAGI confirms the region was added
	FeagiCore.feagi_local_cache.brain_regions.region_added.connect(_on_region_added)
		

func _add_button_pressed() -> void:
	var selected: Array[GenomeObject] = []
	selected.assign(_scroll_section.get_key_array())
	var config: SelectGenomeObjectSettings = SelectGenomeObjectSettings.config_for_multiple_objects_moving_to_subregion(
		FeagiCore.feagi_local_cache.brain_regions.get_root_region(),
		selected)
	var genome_window:WindowSelectGenomeObject = BV.WM.spawn_select_genome_object(config)
	genome_window.final_selection.connect(_selection_complete)

func _selection_complete(array: Array[GenomeObject]) -> void:
	_scroll_section.remove_all_items()
	for object in array:
		_scroll_section.add_text_button_with_delete(object, object.friendly_name, Callable())
	

func _create_region_button_pressed() -> void:
	var region: BrainRegion = _region_drop_down.get_selected_region()
	var selected: Array[GenomeObject] = []
	selected.assign(_scroll_section.get_key_array())
	var region_name: StringName = _name_box.text
	
	# 🎯 FOLLOW CORTICAL AREA PATTERN: Generate random 2D position instead of averaging
	var rand: RandomNumberGenerator = RandomNumberGenerator.new()
	var coords_2D: Vector2i = Vector2i(rand.randi_range(-100, 100), rand.randi_range(-100, 100))
	
	var coords_3D: Vector3i = _vector.current_vector
	
	# 🚨 DEBUG: What coordinates are we using?
	print("🏗️ REGION CREATION: 2D=%s, 3D=%s" % [coords_2D, coords_3D])
	
	if region_name == "":
		var popup: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("No Name", "Please define a name for your Brain Region!")
		BV.WM.spawn_popup(popup)
		return
	FeagiCore.requests.create_region(region, selected, region_name, coords_2D, coords_3D)
	close_window()
	if _preview:
		_preview.cleanup()
		_preview = null

func _on_preview_coords_changed(new_coords: Vector3i) -> void:
	if _preview:
		_preview.update_position_with_new_FEAGI_coordinate(new_coords)

func _clear_existing_region_previews() -> void:
	var bm := BV.UI.temp_root_bm
	if bm == null:
		return
	for child in bm._node_3D_root.get_children():
		if child is UI_BrainMonitor_BrainRegionPreview:
			(child as UI_BrainMonitor_BrainRegionPreview).cleanup()

func _on_region_added(_new_region: BrainRegion) -> void:
	# FEAGI confirmed creation; ensure preview is removed
	if _preview:
		_preview.cleanup()
		_preview = null
	if FeagiCore.feagi_local_cache.brain_regions.region_added.is_connected(_on_region_added):
		FeagiCore.feagi_local_cache.brain_regions.region_added.disconnect(_on_region_added)

func _exit_tree() -> void:
	# Safety cleanup if window closed via other path
	if _preview:
		_preview.cleanup()
		_preview = null
	if FeagiCore.feagi_local_cache.brain_regions and FeagiCore.feagi_local_cache.brain_regions.region_added.is_connected(_on_region_added):
		FeagiCore.feagi_local_cache.brain_regions.region_added.disconnect(_on_region_added)
